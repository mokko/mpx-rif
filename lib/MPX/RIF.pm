package MPX::RIF;

use warnings;
use strict;
use utf8;
use FindBin;
use Carp qw(croak carp);
use File::Find::Rule;

#use IO::File;

use lib "$FindBin::Bin/../lib";
use MPX::RIF::Helper qw(debug log);
use MPX::RIF::Resource;

#works also with XML::Syck in case that is easier to install
use YAML::XS qw (LoadFile DumpFile);

use Date::Manip;
use Time::HiRes qw(gettimeofday);    #to generate unique tokens
use SOAP::DateTime;

use XML::LibXML;
use XML::Writer;

#TODO: more config
our $temp = {
	1 => '1-scandir.yml',
	2 => '2-parsedir.yml',
	3 => '3-objId.yml',
	4 => '4-filter.yml',
	5 => 'mume.mpx'
};

=head1 NAME

MPX::RIF - The great new MPX::RIF!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Read a yaml config file, parse a directory, extract information from filepath
write it in human-readable format for debugging and write MPX Mulitmediaobjekt
information (XML).

    use MPX::RIF;

    my $faker = MPX::RIF->new(%config);
    my $faker->run; #run calls all the steps in the normal order
    #alternatively you can call the steps yourself

	#1st step
	$faker->scandir();

	#2nd step
	$faker->parsedir();

	#3rd step
	$faker->lookupObjId();

	#4th step
	$faker->filter();

	#5th step
	$faker->writeXML();

	#6th step
	$faker->validate();

	#Everything else is considered to be the private parts of this module.
	#For more info see the method run (overview) and the individual methods.


=head1 SUBROUTINES/METHODS

=head2 my $faker=MPX::RIF::new (%CONFIG);

REQUIRED
config is the path to a yaml configuration file.
	CONIG=>'/path/to/config.yml'

	Config file parameters are described inside the example config.

OPTIONAL
	BEGIN => 1 #makes MPX::RIF start with yml file
				0 for off
				1 read scandir from yml file
				2 read parsedir from yml file
				3 read lookup from yml file
	DEBUG=>1, # turns debug messages on/off; 1 for on - 0 for off
	STOP=> 1, # stop after step 1,
				0 don't stop
				1 stop after step 1,
				2 stop after step 2,
				3 stop after step 3,
				4 and higher - ignored (same as 0)

=cut

sub new {
	my $class = shift;
	my $opts  = shift;

	if ( !$opts ) {
		croak "Internal Error: No options!";
	}
	my $self = _loadConfig($opts);
	bless $self, $class;

	#map the module options into the faker object
	$self->_addCLI($opts);

	#check if config makes sense
	$self->_config();

	log "START";

	return $self;
}

=head2 $faker->lookupObjId ('path/to/big-file.mpx');

3rd step. Associate each resource with an objId. Also filter stuff out
that does not have required information.

=cut

sub lookupObjId {
	my $self   = shift;
	my $mpx_fn = $self->{lookup};

	if ( !$mpx_fn ) {
		die 'ERROR: loopupObjId - cannot execute since no mpx data '
		  . 'specified!';
	}

	#debug "Enter lookupObjId";

	# loop over all resources
	# at this point I should NOT need to check anymore if
	# identNr exists
	foreach my $id ( $self->_resourceIds ) {
		my $resource = $self->_getResource($id);
		my $identNr  = $resource->get('identNr');
		if ($identNr) {
			my $objId = $self->_lookupObjId($identNr);

			#take out the identNr, not needed anymore!
			delete $resource->{identNr};

			if ($objId) {
				$resource->addFeatures( 'verknüpftesObjekt' => $objId );
			}
		}
		$self->_storeResource($resource);
	}
	$self->_dumpStore( $temp->{3} );
	$self->stop(3);

}

=head2 $faker->$filter;

4th step. Drops resources from store if they don't have specified keys.

a new step

=cut

sub filter {
	my $self       = shift;
	my @obligatory = qw(verknüpftesObjekt);

	debug "Enter filter";

	foreach my $id ( $self->_resourceIds ) {
		my $resource = $self->_getResource($id);

		#debug "filter:$id";

		my $ok = 1;
		foreach my $feat (@obligatory) {
			my $value = $resource->get($feat);
			if ( !$value ) {
				debug "filter drop: $id has no $feat";

				#I already have a log warning that objId could not be
				#identified, so need not log it again
				#this might change if verknüpftesObjekt is not the only
				#obligatory anymore
				#log "filter drop: $id has no $feat";
				$ok = 0;
			}
		}

		if ( $ok == 0 ) {
			delete $self->{data}->{$id};
		}
	}
	$self->_dumpStore( $temp->{4} );
	$self->stop(4);
}

=head2 my $objId=$self->_lookupObjId;

return () on failure.

=cut

sub _lookupObjId {
	my $self    = shift;
	my $identNr = shift;

	#necessary to run _lookupObjId
	if ( !$self->{xpc} ) {
		$self->_loadMPX;
	}
	my $doc = $self->{xpc};

	if ( !$doc ) {
		die "Something went terribly wrong";
	}

	if ( !$identNr ) {
		croak "Internal Error: _lookupObjId called without identNr";
	}

	#debug "Enter _lookupObjId (look for $identNr)";

	my @nodes = $doc->findnodes(
"mpx:museumPlusExport/mpx:sammlungsobjekt[mpx:identNr = '$identNr' ]/\@objId"
	);

	#return empty handed if no objId found
	if ( !@nodes ) {

		#debug "xpath returns zero nodes";
		return ();
	}

	if ( scalar @nodes > 1 ) {
		my $msg = "IdentNr $identNr not unique in mpx " . $self->{lookup};
		log $msg;
		debug $msg;
		return ();
	}

	#debug "nodes found" . scalar @nodes;
	my $objId = $nodes[0]->string_value();
	debug "ObjId IDENTIFIED $objId";

	return $objId;
}

=head2 $faker->parsedir

Second step.

Will call extension to extract information from file name and
path. Also adds constants.

Naming convention: Every file that is recognized by the find rules specified
in the config.yml is treated as an object with one or several features.

=cut

sub parsedir {
	my $self = shift;
	debug "Parse dir ...";

	foreach my $id ( $self->_resourceIds ) {
		my $resource = $self->_getResource($id);

		#debug "SYD: $resource" . ref $resource;
		$resource = $self->_dirparser($resource);
		$resource->addConstants( $self->{constants} );

	}

	$self->_dumpStore( $temp->{2} );
	$self->stop(2);

}

=head2 $faker->run();

Executes all steps one after according to configuration.

The steps are
 (1) scandir - Read the directory specified in configuration recursively,
               filter files of one or several types (extensions), write
               the resulting file list in the resource store, dump the
               store (containing the file list) as yaml (for debugging
               purposes).
               If option STOP=1 is specified the MPX::RIF will exit here.

 (2) parsedir - Parse the filepath for information. This is done in an external
 			   module since it is very specific to the project, e.g. different
 			   for MIMO than for 78s. The result is saved in the resource
 			   store and dumped to yaml for debugging.

 (3) objIdloopup - To add the metadata of the resource store to existing mpx
 			   data we need to add the right objId to each multimediaObjekt.
 			   We look this information up in one big xml file which should
 			   contain all exported Sammlungsobjekte.

 			   I will probably need to write yet another script that dumps such
 			   a complete mpx file from the OAI data provider.

 			   Resource store is dumped as yaml to check if this step was
 			   successful.

 (4) filter - If a resource lacks one of a list of required features, the
			   resource is dropped (deleted) form the resource store.

 (5) writeXML - The resource store is converted to XML-MPX or more precisely to
 			   multimediaobjekt-records. The resulting file will be manually
 			   inserted into existing big mpx file and (re)imported in the OAI
 			   data provider. (Alternatively, I could write a variant of the
 			   digester which digests mulitmediaobjekte.)

 (6) validate - validate XML and check for duplicate mulId

=cut

sub run {
	my $self = shift;

	#
	#STEP 1:- SCANDIR
	#

	#nothing specified - proceed normally
	if ( $self->{BEGIN} < 1 ) {
		$self->scandir;    #read a dir recursively
	}

	#read scandir from yml instead from dir
	if ( $self->{BEGIN} == 1 ) {
		debug "LOAD SCANDIR YML";
		$self->_loadStore( $temp->{1} );
	}

	#do nothing if BEGINNING is over 1

	#
	#STEP2 - PARSEDIR
	#

	if ( $self->{BEGIN} < 2 ) {
		$self->parsedir;    #parse filepaths with external parser
	} elsif ( $self->{BEGIN} == 2 ) {
		debug "BEGIN WITH SCANDIR YML";
		$self->_loadStore( $temp->{2} );

	}

	#
	# STEP 3 lookup
	#
	if ( $self->{BEGIN} < 3
		or ( !$self->{BEGIN} ) )
	{
		$self->lookupObjId;
	} elsif ( $self->{BEGIN} == 3 ) {
		debug "BEGIN WITH LOOKUP YML";
		$self->_loadStore( $temp->{3} ) or die "Cannot load yml";
	}

	#
	# STEP 4 - filter
	#
	if ( $self->{BEGIN} < 6
		or ( !$self->{BEGIN} ) )
	{

		$self->filter();
	}

	#
	# STEP 5 writeXML
	#
	if ( $self->{BEGIN} < 6
		or ( !$self->{BEGIN} ) )
	{

		$self->writeXML;
	}

	#
	# STEP 6 validate
	#
	if ( $self->{BEGIN} == 6
		or ( !$self->{BEGIN} ) )
	{
		$self->validate;
	}

	debug "done\n";
}

=head2 $faker->scandir

First step. Just scans the directory according to info from configuration file.
It saves info into a yml file (1-scandir.yml) for manual proof reading. Use the
STOP option during initialization to abort after this step, e.g.
 MPX::RIF->new (STOP=>1);

=cut

sub scandir {
	my $self = shift;
	my @name = ['*'];

	if ( $self->{filter} ) {
		@name = $self->{filter};
	}

	debug "Scan dir ...";

	my $dir   = $self->{scandir};
	my @found = File::Find::Rule->file()->name(@name)->in($dir);

	foreach my $path (@found) {
		debug "scandir: $path";

		if ($path) {

			#make a resource that has path as id
			my $resource = MPX::RIF::Resource->new( id => $path );

			#store resource main object
			$self->_storeResource($resource);
		}

	}

	$self->_dumpStore( $temp->{1} );
	$self->stop(1);
}

=head2 $self->validate();

Validate resulting mpx and check for duplicate mulIds. Log errors.

=cut

sub validate {
	my $self = shift;
	my $doc;    #will store parsed xml

	if ( !$self->{mpxxsd} ) {
		debug "Cannot find schema, cannot validate";
		return ();
	}

	debug "Begin validation";

	#if no output then load from file
	if ( $self->{output} ) {
		$doc = XML::LibXML->new->parse_string( $self->{output} );
	} else {
		debug "Load $temp->{5}";
		$doc = XML::LibXML->new->parse_file( $temp->{5} );
	}

	#todo: URI has to go somewhere else. In some configuration
	my $xmlschema = XML::LibXML::Schema->new( location => $self->{mpxxsd} );

	eval { $xmlschema->validate($doc); };

	if ($@) {
		my $msg = "mpx failed validation: $@";
		log $msg;
		debug $msg;
	} else {
		debug "mpx validates\n";
	}

	#
	# todo - check for duplicate mulIds
	#

	my $xpath  = '/mpx:museumPlusExport/mpx:multimediaobjekt/@mulId';
	my $xpc    = registerNS($doc);
	my @mulIds = $xpc->findnodes($xpath);
	debug "no of mulIds ". scalar @mulIds;

	my %seen;
	foreach my $mulId (@mulIds) {
		$mulId=$mulId->getValue;
		$seen{$mulId}++;
		if ( $seen{$mulId} > 1 ) {
			my $msg ="mulId $mulId not unique!";
			debug $msg;
			log $msg;
		}
	}
}

sub registerNS {
	my $doc = shift;
	my $xpc = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs( 'mpx', 'http://www.mpx.org/mpx' );
	return $xpc;
}

=head2 $self->writeXML();
	TODO: maybe I should check if an resource is complete before I xml-ify it

=cut

sub writeXML {
	my $self = shift;

	debug "Begin writingXML";
	my $output;
	my $mpx_ns = 'http://www.mpx.org/mpx';

	my $writer = new XML::Writer(
		NEWLINES   => 0,
		NAMESPACES => 1,
		PREFIX_MAP => {
			$mpx_ns                                     => '',
			'http://www.w3.org/2001/XMLSchema-instance' => 'xsi'
		},
		DATA_INDENT => 2,
		ENCODING    => 'utf-8',
		OUTPUT      => \$output
	);

	$writer->xmlDecl("UTF-8");
	$writer->forceNSDecl($mpx_ns);
	$writer->startTag('museumPlusExport');

	$main::TZ = "CET";

	#FOREACH multimediaobjekt
	foreach my $id ( $self->_resourceIds ) {
		debug "xmlifying $id";

		my $resource = $self->_getResource($id);

		# now in XSD DateTime Format!
		my $time = time();
		my $now  = ConvertDate( ParseDateString("epoch $time") );

		#old mulId
		#my ( $sec, $msec ) = gettimeofday;
		#my $mulId = $time . $msec;

		#new mulId
		my $objId = $self->{data}->{$id}->get('verknüpftesObjekt');
		my $pref  = $self->{data}->{$id}->get('pref');

		#current mpx required mulID to be an integer
		my $mulId;
		if ( $objId && $pref ) {
			$mulId = $objId . '00000' . $pref;
			debug "NEW mulId $mulId";

			my %attributes = (
				'exportdatum' => $now,
				'mulId'       => $mulId,
			);

			#my $pref=$resource->get('pref');
			if ( my $pref = $resource->get('pref') ) {
				$attributes{'priorität'} = $pref;
				delete $self->{data}->{$id}->{pref};
			}

			#my $freigabe=$resource->get('freigabe');
			if ( my $freigabe = $resource->get('freigabe') ) {
				$attributes{'freigabe'} = $freigabe;
				delete $self->{data}->{$id}->{freigabe};
			}

			$writer->startTag( 'multimediaobjekt', %attributes );

			#this should be elsewhereş
			#$resource->path2mpx('id');
			$resource->rmFeat('id');

			#delete $resource->{id};

			foreach my $feat ( $resource->loopFeatures ) {
				my $value = $resource->get($feat);
				$writer->dataElement( $feat, $value );
			}
			$writer->endTag('multimediaobjekt');
		}
	}

	$writer->endTag('museumPlusExport');
	$writer->end();

	debug "about to write XML";
	open( my $fh, '>:encoding(UTF-8)', $temp->{5} ) or die $!;
	print $fh $output;
	close $fh;
	$self->stop(5);

	$self->{output} = $output;
}

=head1 HELPER METHODS

=head2 $self->stop ($location);

Location is the number of the step where stop is called from. If location
matches the $self->{STOP}, MPX::RIF stops gracefully and outputs an a
log and or debug message (if debug and log are on).

=cut

sub stop {

	my $self     = shift;
	my $location = shift;

	if ($location) {
		if ( $self->{STOP} != $location ) {
			return 1;
		}
	}

	log "STOP (exit gracefully)";
	debug "Exit here since stop parameter is given";
	exit 0;
}

=head2 testparser($ilepath);

Just to illustrate how simple the extension could be. It expects a single
filepath and returns a hashref with key/value pairs, like this:

$object={
	key=>value,
	identNr=>'12345d',
}

might soon be superseded by MPX::RIF::Resource

=cut

sub testparser {
	my $filepath = shift;
	my $item     = {
		ok     => 'alles klar',
		consti => 'konstant',
	};
	return $item;
}

=head1 INTERNAL INTERFACE

=cut

sub _addCLI {
	my $self = shift;
	my $opts = shift;

	#if ( $opts->{VERBOSE} ) {
	#	$self->{VERBOSE} = $opts->{VERBOSE};
	#}

	MPX::RIF::Helper::init_log();

	if ( $opts->{DEBUG} ) {
		MPX::RIF::Helper::init_debug();
		debug "Debug mode on";
	}

	if ( $opts->{BEGIN} ) {
		$self->{BEGIN} = $opts->{BEGIN};
		if ( $self->{BEGIN} > 6 ) {
			$self->{BEGIN} = 0;
		}
		debug "BEGIN mode on: " . $self->{BEGIN};
	} else {
		$self->{BEGIN} = 0;
	}

	if ( $opts->{STOP} ) {
		$self->{STOP} = $opts->{STOP};
		debug "STOP mode on: " . $self->{STOP};
	} else {
		$self->{STOP} = 0;
	}

	if ( $opts->{TESTDATA} ) {

		#dump file and exit
		$self->_testData();
	}

}

sub _config {
	my $self = shift;

	debug "Check consistency of configuration";

	#foreach ( keys %{$self} ) {
	#	debug "$_\n   $self->{$_}";
	#}

	my @mandatory = qw/scandir dirparser/;

	my $err = 0;
	foreach my $item (@mandatory) {
		if ( !$self->{$item} ) {
			print "Configuration problem: Mandatory item $item missing in "
			  . "config file\n";
			$err++;
		}
	}
	if ( $err > 0 ) {
		print "Exit here due to configuration problems\n";
		exit 1;
	}

	#specific tests
	if ( !$self->{BEGIN} ) {
		if ( !-e $self->{scandir} ) {
			print "Error: Specified scandir does not exit ($self->{scandir})\n";
			exit 1;
		}

		if ( !-d $self->{scandir} ) {
			print "Error: Scandir is no directory\n";
			exit 1;
		}
	}

	if ( !$self->{lookup} ) {
		debug "Warning: Lookup mpx not specified in config";
	} else {

		if ( !-f $self->{lookup} ) {
			print "Warning: Lookup mpx file not found\n";
		}
	}

	#
	# load the extensions
	#

	if ( !-f $self->{callbackPath} ) {
		print "Error: Extensions file not found $self->{callbackPath}\n";
		exit 1;
	}
	local $@;
	eval { require $self->{callbackPath} };

	#my $error = $@;
	#debug "Error after eval: $error";

	if ( !$self->_dirparserDefined ) {
		print "Error: Dirparser callback function not found!\n";
		exit 1;
	}
}

=head2 if ($self->_dirparserDefined)

=cut

sub _dirparserDefined {
	my $self = shift;
	no strict 'refs';
	if ( defined &{ $self->{dirparser} } ) {

		#debug "get here: $self->{dirparser}";
		return 1;
	}

	#todo: should I return 0 on fail?
}

=head2 my $ret=$faker->dirparser ($path);

Calls the dirparser callback specified in config.yml. Expects a single path.
Returns a hashref representing one object. If something is returned the result
is saved in $self->{data};

my $object={
	key=>value,
	feature=>blue,
}

=cut

sub _dirparser {
	my $self     = shift;
	my $resource = shift;

	if ( !$resource ) {
		carp "_dirparser called without ";
	}
	no strict 'refs';

	#new resource
	my $new = $self->{dirparser}($resource);

	#debug "new:".ref $new;

	if ( !$new ) {
		croak "dirparser returned empty";
	}

	$self->_storeResource($new);

}

sub _loadMPX {
	my $self   = shift;
	my $parser = XML::LibXML->new();
	my $doc    = $parser->parse_file( $self->{lookup} );
	my $xpc    = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs( 'mpx', 'http://www.mpx.org/mpx' );
	$self->{xpc} = $xpc;
}

=head2 $self->_loadStore('path/to/store.yml');
=cut

#load store from YAML file.
sub _loadStore {
	my $self     = shift;
	my $store_fn = shift;

	if ( !$store_fn ) {
		carp "INTERNAL ERROR: Don't know what to load!";
	}

	my $data = LoadFile($store_fn)
	  or die "Cannot load store ($store_fn)!";
	if ( !$data ) {
		print "Error: Store read, but no data!";
		exit 1;
	}
	$self->{data} = $data;
}

=head2 $self->_dumpStore('path/to/store.yml');
=cut

sub _dumpStore {
	my $self     = shift;
	my $filepath = shift;
	debug "Dump store: $filepath";
	DumpFile( $filepath, $self->{data} );

}

sub _loadConfig {
	my $opts = shift;

	#load config file into the faker object
	if ( !$opts->{CONFIG} ) {
		croak "Internal Error: CONFIG not specified!";
	}

	if ( !-f $opts->{CONFIG} ) {
		croak "Internal Error: config file not found!";
	}

	return LoadFile( $opts->{CONFIG} );
}

=head2 	$self->_storeResource ($resource);

Stores the resource in the data store. Requires resource to have an id.

If I don't want redundancy, i.e. the id twice, I need to extract it when I save
it and reinstate when I get it back. Sofar I, only access from _resources.

=cut

sub _storeResource {
	my $self     = shift;
	my $resource = shift;

	if ( !$resource ) {
		croak "_storeResource: no object specified";
	}

	#debug "!!Resource" . ref $resource;
	my $id = $resource->get('id');

	if ( !$resource->get('id') ) {
		croak "cannot store resource since it has no id";
	}
	delete $resource->{id};

	#if I store a reference to the object like this, it doesn't get stored in
	#the yaml file, so I have to make
	$self->{data}->{$id} = $resource;

}

sub _testData {
	my $self = shift;

	debug "LOAD TEST DATA";
	log "LOAD TEST DATA";

	#delete existing data store
	#delete $self->{data};

	my $resource =
	  MPX::RIF::Resource->new( id => 'path/to/fotograf/VII 123 a.JPG' );
	$resource->addFeatures(
		fotograf => 'fotograf',
		identNr  => 'VII 123 a'
	);
	$self->_storeResource($resource);

	$resource =
	  MPX::RIF::Resource->new( id => 'path/to/motograf/VII 223 a.JPG' );
	$resource->addFeatures(
		fotograf => 'motograf',
		identNr  => 'VII 223 a'
	);
	$self->_storeResource($resource);
	$self->_dumpStore('testData.yml');
	exit 0;
}

=head @arr=$self->_resourceIds();


OLD: Don't know how to do this:

Returns one resource at a time from the resource store. Use in while
(preferred) or foreach, e.g.:

 foreach my $resource ($self->_resources()) {
	#bla
 }

=cut

sub _resourceIds {
	my $self = shift;
	if ( !$self->{data} ) {
		carp "_resources called, but faker has no data to loop";
	}

	return keys( %{ $self->{data} } );

	#debug "XXXXXXXXXXxx".@arr;
	#foreach my $id (@arr) {
	#	debug "_RESOURCE $id";
	#	my $resource = $self->{data}->{$id};

	#avoid redundant ids in yaml
	#	$resource->{id} = $id;

	#debug "DDD: maurice: $resource".ref $resource;
	#	return $resource;
	#}

	#returns id and not resource
	#return keys( %{ $self->{data} } );
}

=head2 my $resource=$self->_getResource ($id);

=cut

sub _getResource {
	my $self = shift;
	my $id   = shift;

	if ( !$id ) {
		croak "_getResource called without id!";
	}

	if ( !$self->{data}->{$id} ) {
		carp "_getResource called with non-existant id";
	}

	my $resource = $self->{data}->{$id};

	#avoid redundant ids in yaml
	$resource->{id} = $id;
	return $resource;
}

=head1 AUTHOR

Maurice Mengel, C<< <mauricemengel at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mpx-rif at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MPX-RIF>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MPX::RIF


You can also look for information at:

github.com/mokko/mpx-rif

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Maurice Mengel.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of MPX::RIF
