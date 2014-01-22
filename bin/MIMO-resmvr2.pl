#!/usr/bin/env perl

# PODNAME: MIMO-resmvr.pl
# ABSTRACT: resource mover for MIMO
# this one has a lot of bad code!
##
## THis vERSION HAS A HARVESTER bUT DoeS NOT WORK
##

use strict;
use warnings;
use Log::Handler;
use XML::LibXML;
use File::Copy;
use YAML::Syck;
use FindBin;
use Path::Class;
use Pod::Usage;
use Image::Magick;
use HTTP::OAI;

use Encode qw(encode_utf8);    #not used currently...
use XML::SAX::Writer;

#assuming that this script will reside at bin/MIMO-resmvr.pl and will not be installed via make install
use lib "$FindBin::Bin/../lib";

#use MPX::RIF::Util qw(registerMPX win2cyg);
use MPX::RIF::Helper qw(error debug registerMPX win2cyg);

use Getopt::Std;
our $counter = 0;              #for resources that were moved/renamed
getopts( 'c:dhpv', my $opts = {} );
pod2usage( -verbose => 2 ) if ( $opts->{h} );

=head1 SYNOPSIS

MIMO-resmvr.pl 
	-d be verbose and print debug information
	-p is a plan only. No file is actually copied.


=head1 DESCRIPTION

This is a variant of the resource mover which talks directly to online
data provider.

For MIMO, we need to upload images to MIMO's FTP server. This script copies
images to a temp directory and renames them using to $mulId.jpg. Currently
ftp process is handled separately.

1. Harvest mpx data from data provider
2. Loop over every multimediaobjekt
3. Check various conditions
4. Move resource file to new location at temp/$mulId.jpg
5. Write a log with all errors

We copy only files for which we have a mulId, hence they also have metadata
describing the image. We produce a readable log file.

=head1 TODO

I have three parts to each image and are three are necessary for each MIMO
image:

a) multimediaobjekt - resource metadata
b) resource file
c) sammlungsobjekt - object metadata

This script primarily looks for resource metadata (loop thur each
multimediaobjekt). This script logs warnings for file specified in mpx, but
cannot be found at this location during runtime.

I do not check if there are files which have no multimediaobjekte. I did not
check if there are dublicate multimediaobjekte.

Should I also check which multimediaobjekt has no verknüpftesObjekt?
Maybe there are multimediaobjekte which are not meant for MIMO? Maybe in a
separate script.

NEW TODO
I could build an onRecord harvester into this little script, so it doesn't need
a current harvest.

=cut

#
# command line sanity
#

#if verbose use debug messages for verbose out
MPX::RIF::Helper::init_debug() if ( $opts->{v} or $opts->{d} );
debug "Debug mode on";

if ( $opts->{p} ) {
	debug "Planning mode on. No file will actually be moved!";
}

#-c or default: conf/$USER.yml
my $config = loadConfig( $opts->{c} );

# INIT LOG
my $log = init_log();

#
# MAIN
#

# INIT MPX from file (harvest from online)

# xpath includes conditions which have to fulfilled to be considered
my $xpc   = init_mpx( $ARGV[0] );
my $xpath = q(/mpx:museumPlusExport/mpx:multimediaobjekt[
  mpx:verknüpftesObjekt and
  mpx:multimediaPfadangabe and
  @freigabe = 'web' or @freigabe = 'Web']);

my @nodes = $xpc->findnodes($xpath);

debug "xpath: $xpath";
debug 'found ' . scalar @nodes . " nodes";

# LOOP THRU multimediaobjekte in file
foreach my $node (@nodes) {
	my $node  = registerMPX($node);
	my $mulId = getMulId($node);

 #act on the file path that is saved in resource description
 #multimediaDateiname, multimediaErweiterung etc.
 #not sure warn is the right thing to do on error. Perhaps a log entry is enough
	my ( $cygPath, $origExt ) = getPath($node)
	  or warn "cygPath not returned!";

	#to move need cygPath, also corrects ext if needed and warns if file
	#not found
	my $newCygPath = newPath( $cygPath, $origExt, $mulId );
	my $todo = imageWork( $cygPath, $newCygPath, $origExt );

	if ($todo) {

		#debug " file will not change, will just renamed and copy";
		#test if resource is found, log warning if not
		if ( -f "$cygPath" ) {
			$counter++;
			if ( !$opts->{p} ) {
				copy( $cygPath, $newCygPath );
			}
		}
		else {
			$log->warning("Resource not found:$cygPath");
		}
	}
}

my $msg;
if ( $opts->{p} ) {
	$msg = "done. $counter files would have been copied/renamed\n";
}
else {
	$msg = "done. $counter files copied/renamed\n";
}
print $msg;
$log->warning($msg);
exit;

#
# SUBs
#

sub newPath {
	my $cygPath = shift or die "Error";
	my $origExt = shift or die "Error";
	my $mulId   = shift or die "Error";

	#make new path, typically: $tempdir/$mulId.jpg
	my $newExt = lc($origExt);

	#TODO: extract this somehow
	#FILE CONVERSIONS
	#if orig is tif convert to jpg
	if ( $newExt =~ /^tif$|^tiff$/ ) {
		$newExt = 'jpg';
	}

	my $newPath = $config->{tempdir} . '/' . $mulId . '.' . $newExt;
	debug "newPath: $cygPath --> $newPath";
	return $newPath;
}

sub getMulId {
	my $node  = shift or die "Error";
	my @arr   = $node->findnodes('@mulId');
	my $mulId = $arr[0]->string_value();

	if ( !$mulId ) {
		die "Error: no mulId";
	}

	return $mulId;
}

=func my $todo=imageWork ($old, $new);

Expects two file paths: the current location and the new location. imageWork 
return 1 if original file still needs to be copied/renamed and nothing it no
such action is required.

imageWork checks if image is bigger 800 px in either width or length. The new version
will be limited to 800 px. It will move those images at new location.

I assume I already tested if $old exists and get here only if it does.

=cut

sub imageWork {
	my $old     = shift or die "Error";
	my $new     = shift or die "Error";
	my $origExt = shift or die "Error";

	#debug "Enter resizeJpg";
	my $p = Image::Magick->new ;
	my ( $width, $height, $size, $format ) = $p->Ping($old);

	if ( !$width ) {
		return 1;    #if not a picture, so just move it
		             #also if file not available
	}

	if (   $width > 800
		or $height > 800
		or $origExt =~ /^tif$|^tiff$/ )
	{
		debug "downsize image";
		$p->Read($old);
		$log->warning("transform $old");
		$p->AdaptiveResize( geometry => '800x800' );
		$counter++;
		if ( !$opts->{p} ) {
			$p->Write($new);
		}
		return;    #on return empty do NOT move!
	}
	else {
		if ( $width < 800 && $height < 800 ) {
			$log->warning("image smaller than 800 px: $old");
		}
		return 1;    #on return move this file anyways!
	}
}

=func my ($cygPath, $ext)=getPath($node);

Expects a multimediaobjekt and returns the path composed of
multimediaPfadangabe, multimediaDateiname, multimediaErweiterung
nach dem Muster 
	Pfad/Dateiname.Erweiterung

	i.e. it working cygpath, not a windows path
	returns full paths as saved in MPX, typically
	M:\\bla\bli\blu\file.jpg

	as cygpath as
	/cygdrive/M/bla/bli/blu/file.jpg

	and the extention (jpg).

=cut

sub getPath {
	my $node = shift or die "Error";
	my @arr;

	my ( $pfad, $datei, $erweiterung );
	@arr = $node->findnodes('mpx:multimediaPfadangabe');
	if ( $arr[0] ) {
		$pfad = $arr[0]->string_value();
		$pfad =~ s,\s*$,,;
	}

	@arr = $node->findnodes('mpx:multimediaDateiname');
	if ( $arr[0] ) {
		$datei = $arr[0]->string_value();
		$datei =~ s,\s*$,,;
	}

	@arr = $node->findnodes('mpx:multimediaErweiterung');
	if ( $arr[0] ) {
		$erweiterung = $arr[0]->string_value();
		$erweiterung =~ s,\s*$,,;
	}

	if ( $pfad && $datei && $erweiterung ) {

		#path is fullpath as specified in MuseumPlus
		#I currently assume that it is always as windows path
		my $path = $pfad . '\\' . $datei . '.' . $erweiterung;

		#debug "getPATH: $path;";
		return win2cyg($path), $erweiterung;
	}

	my $msg = 'Path not complete for mulId ' . getMulId($node);
	debug $msg;
	log->warning($msg);

	return;
}

=func init_log;

Expects location of temp directory in $config->{tempdir}.
Return log object.

=cut

sub init_log {
	if ( !$config->{tempdir} ) {
		die "tempdir not specified!";
	}

	if ( !-d $config->{tempdir} ) {
		debug "tempdir does not exist, trying to mk $config->{tempdir}";
		mkdir $config->{tempdir} or die "Cannot make tempdir!";
	}

	my $log = Log::Handler->new();
	my $logfile = file( $config->{tempdir}, $config->{logfile} )->stringify;

	if ( -f $logfile ) {

		#debug "about to unlink logfile $file";
		unlink $logfile or warn "cannot delete old file $!";
	}

	$log->add(
		file => {
			filename => $logfile,
			maxlevel => 7,
			minlevel => 0
		}
	);
	debug "log to logfile at $logfile";
	return $log;

}

sub harvest {

	my $msg = sprintf "About to harvest '%s' set '%s' from '%s'",
	  $config->{metadataPrefix}, $config->{set}, $config->{baseURL};
	debug $msg;
	$log->warning($msg);

	#this should resume as default, but doesn't
	my $h = HTTP::OAI::Harvester->new( baseURL => $config->{baseURL}, );

	my $lr = $h->ListRecords(
		metadataPrefix => $config->{metadataPrefix},
		set            => $config->{set}
	);
	die $lr->message if $lr->is_error;

	if ( $lr->resumptionToken ) {

		while ( my $rt = $lr->resumptionToken ) {
			debug 'HTTP::OAI does not resume, but it should...';

			$lr->resume( resumptionToken => $rt );
			die $lr->message if $lr->is_error;
		}
	}

	#write to file cache, but continue...
	#$lr->toDOM->toFile( $config->{harvest} );
	my $xml;
	$lr->set_handler( XML::SAX::Writer->new( Output => \$xml ) );
	$lr->generate;
	encode_utf8($xml);
	
	open( my $fh, '> : encoding(UTF-8)', $config->{harvest} )
	  or die 'Error: Cannot write to file:' . $config->{harvest} . '! ' . $!;
	print $fh $xml;
	close $fh;

	#encoding terror
	my $dom = XML::LibXML->load_xml( string => $xml );
	return $dom;

	#i could also try libXML $doc->setEncoding($new_encoding);
	#$lr->set_handler( XML::SAX::Writer->new( Output => /$xml) );
	#$lr->generate;
	#print encode_utf8($xml);
}

=func $xpc=init_mpx ('path/to/mpx');

Opens mpx file with LibXML and registers namespace mpx.

If no file exists at the location $config->{harvest}, initate a new harvest.
Please delete harvest file manually if you want to update. Default location
is at 
	tempdir/harvest.mpx

=cut

sub init_mpx {
	my $doc;
	if ( !-f $config->{harvest} ) {
		debug "NEW harvest";
		$doc = harvest();
	}
	else {
		debug "load last harvest from FILE";
		$doc = XML::LibXML->load_xml( location => $config->{harvest} );
	}

	my $xpc = registerMPX($doc);
	debug "mpx successfully initialized";
	return $xpc;
}

=func loadConfig ($opts)

If no $opts are specified, loads config values from a yml file. That
file spec is guessed based on user name:
	conf/$user.yml

If $opts is specified, it will not look at that location, but try to load
the conf file directory from that location.

Only subvalues of 'resourceMover' are returned.

=cut

sub loadConfig {
	my $optc = shift;

	#default:conf/$user.yml
	if ( !$ENV{USER} ) {
		$ENV{USER} = 'USER';
		debug "Environment variable 'USER' not defined. Assume USER";
	}

	#default
	my $file = file( $FindBin::Bin, '..', 'conf', $ENV{USER} . '.yml' );

	#overwrite default if -c
	$file = $optc if ($optc);

	debug "Trying to load configuration from $file";
	error "Configuration file does not exist ($file)" if ( !-e $file );

	my $config = LoadFile($file) or die "Cannot load config file";
	error 'Configuration loaded, but no resourceMover info'
	  if ( !$config->{resourceMover} );

	#simple validate
	#1) required values
	foreach my $key (qw/tempdir metadataPrefix set baseURL/) {
		error "required configuration key missing: $key"
		  if ( !$config->{resourceMover}{$key} );
	}

	#2) defaults
	if ( !$config->{resourceMover}{harvest} ) {
		$config->{resourceMover}{harvest} =
		  file( $config->{resourceMover}{tempdir}, 'harvest.mpx' )->stringify;
	}

	if ( !$config->{resourceMover}{logfile} ) {
		$config->{resourceMover}{logfile} = 'resmvr.log';
	}

	return $config->{resourceMover};

	#debug $config->{tempdir};
}
