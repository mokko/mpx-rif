#!/usr/bin/perl

use strict;
use warnings;
use Log::Handler;
use XML::LibXML;
use File::Copy;
use YAML::Syck;
use FindBin;
use File::Spec;

use Getopt::Std;
getopts( 'c:d', my $opts = {} );

sub debug;

#my $config = {
#logfile: path where log is to be stored (inside tempdir)
#	logfile => 'MIMO-resmvr.log',
#path where big mpx file lies
#mpx => '/home/Mengel/projects/Salsa_OAI2/data/source/MIMO-May-Export.mpx',
#path where images and log will be stored
#	tempdir => '/home/Mengel/temp',
#};

=head1 NAME

MIMO-resmvr.pl

=head2 SYNOPSIS

MIMO-resmvr.pl [-d] conf/default.yml file.mpx

	TODO:
	-p is a plan only. No file is actually copied.


=head1 DESCRIPTION

For MIMO, we need to upload images to MIMO's FTP server. This script copies
images to a temp directory and renames them using to $mulId.jpg. Currently
ftp process is handled separately.

1. Read a big mpx file
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

=cut

#
# command line sanity
#

if ( !$opts->{d} ) {
	$opts->{d} = 0;
}
debug "Debug mode on";

#-c or default: conf/$USER.yml
my $config = loadConfig( $opts->{c} );

if ( !$ARGV[0] ) {
	print "Error: Need an mpx file!\n";
	exit 1;
}

if ( !-f $ARGV[0] ) {
	print "Error: Mpx file not found!\n";
	exit 1;
}

# INIT LOG
my $log = init_log();

# INIT MPX
my $xpc   = init_mpx( $ARGV[0] );
my $xpath = '/mpx:museumPlusExport/mpx:multimediaobjekt'
  . '[mpx:verknüpftesObjekt and mpx:multimediaPfadangabe]';

#
# MAIN
#

# LOOP THRU multimediaobjekte
my @nodes = $xpc->findnodes($xpath);

debug "xpath: $xpath";
debug 'found ' . scalar @nodes . " nodes";

#my @nodes = $doc->findnodes(
#	    'mpx:museumPlusExport/mpx:multimediaobjekt'
#	  . '[@freigabe = \'web\']'
#);

foreach my $node (@nodes) {
	my $node  = registerNS($node);
	my @arr   = $node->findnodes('@mulId');
	my $mulId = $arr[0]->string_value();

	if ( !$mulId ) {
		die "Error: no mulId";
	}

	my ( $pfad, $datei, $erweiterung );
	@arr = $node->findnodes('mpx:multimediaPfadangabe');
	if ( $arr[0] ) {
		$pfad = $arr[0]->string_value();
	}

	@arr = $node->findnodes('mpx:multimediaDateiname');
	if ( $arr[0] ) {
		$datei = $arr[0]->string_value();
	}

	@arr = $node->findnodes('mpx:multimediaErweiterung');
	if ( $arr[0] ) {
		$erweiterung = $arr[0]->string_value();
	}

	if ( !$pfad && $datei && $erweiterung ) {
		my $msg = "Path not complete for mulId $mulId";
		debug $msg;
		log->warning($msg);
	} else {

		#path is fullpath as specified in MuseumPlus
		#I currently assume that it is always as windows path
		my $path = $pfad . '\\' . $datei . '.' . $erweiterung;

		#convert to nix for cygwin
		$path = cygpath($path);

		#new filename
		my $new = $config->{tempdir} . '/' . $mulId . '.' . lc($erweiterung);
		debug "$path --> $new";

		#test if resource is found, log warning if not
		if ( !-f $path ) {
			$log->warning("Resource not found:$path");
		} else {
			copy( $path, $new );
		}
	}

	#alternatively I could make it ftp it to the right place
}

#
# SUBs
#

sub debug {
	my $msg = shift;
	if ( $opts->{d} > 0 ) {
		print $msg. "\n";
	}
}

sub init_log {
	if ( !$config->{tempdir} ) {
		die "tempdir not specified!";
	}

	if ( !-d $config->{tempdir} ) {
		debug "mkdir $config->{tempdir}";
		mkdir $config->{tempdir} or die "Cannot make tempdir!";
	}

	my $log = Log::Handler->new();

	#*nix path only
	my $logfile = $config->{tempdir} . '/' . $config->{logfile};

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

sub init_mpx {
	my $file = shift;

	die "Internal Error: init_mpx called without file" if (!$file);

	if ( !-e $file ) {
		print "Error: $file does not exist";
		exit 1;
	}

	debug "About to load mpx file ($file)";

	my $parser = XML::LibXML->new();
	my $doc    = $parser->parse_file($file);
	my $xpc    = registerNS($doc);
	debug "mpx successfully initialized";
	return $xpc;
}

sub loadConfig {
	my $optc = shift;

	#default:conf/$user.yml
	if ( !$ENV{USER} ) {
		$ENV{USER} = 'USER';
		debug "Environment variable 'USER' not defined. Assume USER";
	}

	#default
	my $file =
	  File::Spec->catfile( $FindBin::Bin, '..', 'conf', $ENV{USER} . '.yml' );

	#overwrite default if -c
	if ( $optc ) {
		$file = $optc;
	}

	debug "Trying to load $file";

	if ( !-e $file ) {
		print "Error: Configuration file does not exist!\n";
		exit 1;
	}


	my $config = LoadFile($file) or die "Cannot load config file";

	if ( !$config->{resourceMover} ) {
		print "Error: Configuration loaded, but no resourceMover info!\n";
		exit 1;
	}

	return $config->{resourceMover};
	debug $config->{tempdir};

}

sub registerNS {
	my $doc = shift;
	my $xpc = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs( 'mpx', 'http://www.mpx.org/mpx' );
	return $xpc;
}

=head2 my $nix=cygpath ($win);

Convert path from windows to unix. VERY slow and VERY annoying.

=cut

sub cygpath {
	my $in = shift;

	if ( !$in ) {
		die "cypath called without path";
		return ();    #not sure which is better
	}
	my $out = `cygpath '$in'`;
	chomp $out;

	#print '!'.$out."!";
	return $out;
}

#sub win2unix
