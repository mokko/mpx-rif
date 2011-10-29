package MPX::RIF;

# ABSTRACT: build cheap mpx from filenames etc.

use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Carp qw(croak carp);
use Cwd qw (realpath);
use Date::Manip;
use File::Find::Rule;
use File::Spec;
use HTTP::OAI;
use MPX::RIF::Helper qw(debug log);
use MPX::RIF::Resource;
use Time::HiRes qw(gettimeofday);    #to generate unique tokens
use SOAP::DateTime;
use utf8;
use XML::LibXML;
use XML::Writer;
use XML::LibXSLT;
use YAML::XS qw (LoadFile DumpFile);

#works also with XML::Syck in case that is easier to install

#TODO: more config
our $temp = {
	1 => '1-scandir.yml',
	2 => '2-parsedir.yml',
	3 => '3-objId.yml',
	4 => '4-filter.yml',
};

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


=head1 RATIONALE

There are many images. It can take a long to enter them manually in the
database. For each item, there are many repetitive information items, e.g. 1000
fotos were made by the same fotographer.

This little perl tool parses a directory and writes XML/MPX with the metadata.
It is good with repetative metadata. Of course, this is not a silver bullett.
It is a just a cheap solution that works only if you know your photos well.

The whole process is broken down in several consecutive steps. State
information is dumped a couple of times during executing as yaml, to
facilitate proof-reading and error checking. There are debug messages and log
messages which should help you finding quirks in your data.

The tool is configurable. It's written in a haste i.e. no great code, but
it should at least be readable.

=method my $faker=MPX::RIF::new (%CONFIG);

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

	#delete log file

	log "lookup file: " . $self->{lookup};

	return $self;
}

=method $faker->lookupObjId ('path/to/big-file.mpx');

3rd step. Associate each resource with an objId. Also filter stuff out
that does not have required information.

=cut

sub lookupObjId {
	my $self   = shift;
	my $mpx_fn = $self->{lookup};

	#attemp harvest and write new file to disk for debugging
	#avoid with NOHARVEST or -n
	$self->_harvest();

	if ( !$mpx_fn ) {
		die 'ERROR: loopupObjId - cannot execute since no mpx data '
		  . 'specified!';
	}

	# loop over all resources
	# at this point I should NOT need to check anymore if
	# identNr exists
	foreach my $id ( $self->_resourceIds ) {
		my $resource = $self->_getResource($id);
		my $identNr  = $resource->get('identNr');
		if ($identNr) { 
			my $objId = $self->_lookupObjId($identNr);
			#debug "lookup $identNr";
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

=method $faker->$filter;

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

	#if (testWholeA ($identNr)) {
	#	matchIdentNr ($identNr, exact) or
	#	matchIdentNr ($identNr, parts)
	#}

	#if (testWholeB ($identNr)) {
		#my @parts=wholeB2Parts(identNr);
		#foreach (@parts ) {
			#@matches=matchIdentNr ($_, exact); #only one	
			#@matches=matchIdentNr ($_, parts); #can be multiple	
		#}
	#}
	
	#if whole in b-notation try for exactMatch for all parts
	#if while in a notation call variant of exactMatch which ignores 3rd part
	#match (identNr, exact);
	#match (identNr, exactAndParts)
	#testIdentNrWholeA
	#testIdentNrWholeB
	#there can be only one. If several return only latest export
	#objId=exactMatch (IdentNr)

	#debug "Enter _lookupObjId (look for $identNr)";

	#Soll ist Lars Methode: Konvolut-DS soll in M+ sein sowie
	#eigener DS für Unternummern. Damit wir nicht mehrere ObjIds für einen
	#Obj bekommen, filtern wir die IdentNr heraus (Wiederholfeld), die automa
	#tisch von M+ erzeugt werden und mit 'Ident. Unternummer' qualifiziert
	#werden

	#ohne Unternummer
	#my $xpath = q(
	#	mpx:museumPlusExport/mpx:sammlungsobjekt[mpx:identNr
	#	[
	#			@art != 'Ident. Unternummer' or not (@art)
	#	]
	#);
	#mit Unternummer
	my $xpath = q(
		mpx:museumPlusExport/mpx:sammlungsobjekt[mpx:identNr
	);
	$xpath .= qq(= '$identNr']);
	#debug "   xpath:\n   ".$xpath;

	my @nodes = $doc->findnodes($xpath);

	#return empty handed if no objId found
	if ( !@nodes ) {
		my $msg = "'$identNr' NOT FOUND, objId missing";

		debug '   ' . $msg;

		#debug "   xpath:\n   " . $xpath;
		log $msg;

		#debug "xpath returns zero nodes";
		return;
	}

	my $objId = $nodes[0]->findvalue('@objId');

	#return the objId of newest export if NOT unique
	if ( scalar @nodes > 1 ) {
		my $newestObject;

		#debug '  ' . $msg . "\n";
		#debug "   xpath:\n   " . $xpath;
		#debug '   # nodes found: ' . scalar @nodes;

		#take node with newest (i.e. biggest) exportdatum

		my $expdatum = '';
		foreach my $object (@nodes) {
			if ( $object->findvalue('@exportdatum') gt $expdatum ) {
				$newestObject = $object;
			}
		}
		$objId = $newestObject->findvalue('@objId');
		my $msg = "   IDENTIFIED AMBIGUOUS: $identNr-> objId $objId";
		debug $msg;
		log $msg;

	}

	debug "lookupObjId $identNr->$objId";
	return $objId;
}

=method $faker->parsedir

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

=method $faker->run();

Executes all steps one after according to configuration. See mpx-rif.pl for
high-level description.

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
	}
	elsif ( $self->{BEGIN} == 2 ) {
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
	}
	elsif ( $self->{BEGIN} == 3 ) {
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

		#$self->validate;
	}

	debug "done\n";
}

=method $faker->scandir

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

=method $self->validate();

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
	}
	else {
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
	}
	else {
		debug "mpx validates\n";
	}

	#
	# todo - check for duplicate mulIds
	#

	my $xpath  = '/mpx:museumPlusExport/mpx:multimediaobjekt/@mulId';
	my $xpc    = registerNS($doc);
	my @mulIds = $xpc->findnodes($xpath);
	debug "no of mulIds " . scalar @mulIds;

	my %seen;
	foreach my $mulId (@mulIds) {
		$mulId = $mulId->getValue;
		$seen{$mulId}++;
		if ( $seen{$mulId} > 1 ) {

			#results contains multiple nodes
			my $msg     = "mulId $mulId not unique!";
			my @results =
			  $xpc->findnodes(
				"/mpx:museumPlusExport/mpx:multimediaobjekt[\@mulId = $mulId]");
			foreach (@results) {
				$_ = registerNS($_);
				$msg .=
				  "\n   " . $_->findvalue('mpx:multimediaPfadangabe') . '\\';
				$msg .= $_->findvalue('mpx:multimediaDateiname') . '.jpg';
			}
			debug $msg;
			log $msg;
		}
	}
}

=func my $xpc=registerNS ($doc);

Expects DOM or doc, never sure about it. Returns xpc.

Register prefix mpx with http://www.mpx.org/mpx
=cut

sub registerNS {
	my $doc = shift;
	my $xpc = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs( 'mpx', 'http://www.mpx.org/mpx' );
	return $xpc;
}

=method $self->writeXML();
	TODO: maybe I should check if an resource is complete before I xml-ify it

=cut

sub writeXML {
	my $self = shift;
	my $i    = 0;       #count mume records

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

		#new mulId now with number dependent file suffix
		my $objId  = $self->{data}->{$id}->get('verknüpftesObjekt');
		my $pref   = $self->{data}->{$id}->get('pref');
		my $suffix = $self->{data}->{$id}->get('multimediaErweiterung');
		$suffix =
		    sprintf( "%02d", MPX::RIF::MIMO::alpha2num( substr $suffix, 0, 1 ) )
		  . sprintf( "%02d", MPX::RIF::MIMO::alpha2num( substr $suffix, 1, 1 ) )
		  . sprintf( "%02d",
			MPX::RIF::MIMO::alpha2num( substr $suffix, 2, 1 ) );

		#debug "SSSSSSSSSSSSSSSSSuffix: " . $suffix;

		#current mpx required mulID to be an integer
		my $mulId;
		if ( $objId && $pref ) {
			$mulId = $objId . $suffix . $pref;

			#debug "NEW mulId $mulId";

			my %attributes = (
				'exportdatum' => $now,
				'mulId'       => $mulId,
				'quelle'      => 'mpx-rif',
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
			$i++;
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

	log "$i mume records written";

	print "about to write XML to $self->{output}\n";
	open( my $fh, '>:encoding(UTF-8)', $self->{output} ) or die $!;
	print $fh $output;
	close $fh;

	$self->stop(5);
	$self->{output} = $output;
}

=method $self->stop ($location);

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

=func testparser($ilepath);

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
	if ( $opts->{NOHARVEST} ) {
		$self->{NOHARVEST} = 1;
	}

	if ( $opts->{DEBUG} ) {
		MPX::RIF::Helper::init_debug();
		debug "Debug mode on";
	}

	MPX::RIF::Helper::unlink_log();
	MPX::RIF::Helper::init_log();

	if ( $opts->{BEGIN} ) {
		$self->{BEGIN} = $opts->{BEGIN};
		if ( $self->{BEGIN} > 6 ) {
			$self->{BEGIN} = 0;
		}
		debug "BEGIN mode on: " . $self->{BEGIN};
	}
	else {
		$self->{BEGIN} = 0;
	}

	if ( $opts->{STOP} ) {
		$self->{STOP} = $opts->{STOP};
		debug "STOP mode on: " . $self->{STOP};
	}
	else {
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

	my @mandatory = qw/scandir dirparser dataProvider output/;

	my $err = 0;
	foreach my $item (@mandatory) {
		if ( !$self->{$item} ) {
			print "Configuration problem: Mandatory item '$item' missing in "
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
	}
	else {

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

sub _dirparserDefined {
	my $self = shift;
	no strict 'refs';
	if ( defined &{ $self->{dirparser} } ) {

		#debug "get here: $self->{dirparser}";
		return 1;
	}

	#todo: should I return 0 on fail?
}

=method my $ret=$faker->_dirparser ($path);

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

=method $self->_loadStore('path/to/store.yml');
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

=method $self->_dumpStore('path/to/store.yml');
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

=method	$self->_storeResource ($resource);

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

=method @arr=$self->_resourceIds();


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

=method my $resource=$self->_getResource ($id);

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

sub _harvest {
	my $self   = shift or return;
	my $mpx_fn = $self->{lookup};

	if ( $self->{NOHARVEST} ) {
		debug "NOHARVEST switch actived. Will not attempt to harvest";
		return;
	}

	debug "About to query data provider: $self->{dataProvider}";

	my $harvester =
	  HTTP::OAI::Harvester->new( baseURL => $self->{dataProvider}, );

	my $response = $harvester->ListRecords(
		metadataPrefix => 'mpx',
		set            => 'MIMO',
	);

	if ( $response->is_error ) {
		warn( "Error harvesting: " . $response->message . "\n" );
	}

	while ( my $rt = $response->resumptionToken ) {
		debug 'harvesting ' . $rt->resumptionToken;
		$response->resume( resumptionToken => $rt );
		if ( $response->is_error ) {
			warn( "Error resuming: " . $response->message . "\n" );
		}
	}

	if ( !$response->is_error ) {

		#scalar ref so we can avoid having two of them in memory
		_unwrapAndWrite( $mpx_fn, \$response );
	}

}

sub _unwrapAndWrite {
	my $mpx_fn = shift or die "Error!";
	my $big    = shift or die "Error!";    # scalar ref to response
	debug "Start unwrapping...";
	${$big} = _unwrap( ${$big}->toDOM );
	debug "About to write harvest to $mpx_fn";
	${$big}->toFile( $mpx_fn, 0 );
	undef ${$big};
	debug "Written to file $mpx_fn";
}

sub _unwrap {
	my $dom = shift or die "Need response";
	my $unwrapFN =
	  realpath(
		File::Spec->catfile( $FindBin::Bin, '..', 'xsl', 'unwrap.xsl' ) );
	if ( !-f $unwrapFN ) {
		die "$unwrapFN not cound. Check bin../xsl/unwrap.xsl";
	}

	my $xslt      = XML::LibXSLT->new();
	my $style_doc = XML::LibXML->load_xml(
		location => $unwrapFN,
		no_cdata => 1
	);

	my $stylesheet = $xslt->parse_stylesheet($style_doc);

	#now dom
	return $stylesheet->transform($dom);
}

1;    # End of MPX::RIF
