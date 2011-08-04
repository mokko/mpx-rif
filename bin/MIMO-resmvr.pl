#!/usr/bin/env perl

# PODNAME: MIMO-resmvr.pl
# ABSTRACT: resource mover for MIMO

use strict;
use warnings;
use Log::Handler;
use XML::LibXML;
use File::Copy;
use YAML::Syck;
use FindBin;
use File::Spec;
use Image::Magick;

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

=head1 SYNOPSIS

MIMO-resmvr.pl [-d] file.mpx

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

	my ($win, $erweiterung) = getPath($node);
	if (!$win) {
		my $msg = "Path not complete for mulId $mulId";
		debug $msg;
		log->warning($msg);
		next; #untested

	}

	#convert to nix for cygwin
	#my $path = cygpath($win);
	my $path = win2cyg($win);

	#new filename
	my $new = $config->{tempdir} . '/' . $mulId . '.' . lc($erweiterung);
	debug "$path --> $new";

	#test if resource is found, log warning if not
	if ( !-f "$path" ) {
		$log->warning("Resource not found:$path");
	} else {
		debug 'er'.lc($erweiterung);
		if (lc($erweiterung) eq 'jpg') {
			resizeJpg ($path,$new);
		} else {
			copy( $path, $new );
		}
	}
}


#
# SUBs
#

=func resizeJpg ($old, $new);

Expects two file paths: the current location and the new location. It will
check if image is bigger 800 px in either width or length. The new version
will be limited to 800 px.

I assume I already tested if $old exists and get here only if it does.

=cut

sub resizeJpg {
	my $old=shift;
	my $new=shift;

	#debug "Enter resizeJpg";

	if (!$old) {
		die "resizeJpg: no file name old!";
	}

	if (!$new) {
		die "resizeJpg: no file name new!";
	}

	my $p=new Image::Magick;
	my ($width, $height, $size, $format) = $p->Ping($old);

	if ($width > 800 or $height > 800) {
		debug "downsize image";
		$p->Read ($old);
		$log->warning("Downsize $old");
		$p->AdaptiveResize(geometry=>'800x800');
		$p->Write ($new);
	} else {
		if ($width < 800 && $height < 800) {
			$log->warning("image $old is smaller than 800 px");
		}
		#if size ok just cp to new location
		copy( $old, $new );
	}
}

=func my ($path, $erweiterung)=getPath($node);

	returns full paths as saved in MPX, typically
	M:\\bla\bli\blu\file.jpg

=cut

sub getPath {
	my $node = shift;
	my @arr;

	if ( !$node ) {
		die "extractPathFromMume called without node";
	}

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
		return $path, $erweiterung;
	}

	return;
}

=func debug 'message';

print debug messages to STDOUT. A newline is added at the end of every debug
message.

=cut

sub debug {
	my $msg = shift;
	if ( $opts->{d} > 0 ) {
		print $msg. "\n";
	}
}

=func init_log ($tempdir);

Return value?

=cut

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

=func $xpc=init_mpx ('path/to/mpx');

Opens mpx file with LibXML and registers namespace mpx.

=cut

sub init_mpx {
	my $file = shift;

	die "Internal Error: init_mpx called without file" if ( !$file );

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
	my $file =
	  File::Spec->catfile( $FindBin::Bin, '..', 'conf', $ENV{USER} . '.yml' );

	#overwrite default if -c
	if ($optc) {
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

=func my $xpc=registerNS ($doc);
=cut
sub registerNS {
	my $doc = shift;
	my $xpc = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs( 'mpx', 'http://www.mpx.org/mpx' );
	return $xpc;
}

=head2 my $nix=cygpath ($win);

DEPRECATED. Convert path from windows to unix. VERY slow and VERY annoying.
Not used anymore. See win2cyg instead.

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

=head2 my $cyg=win2cyg($win);

very simple re-implementation of cygpath.

=cut

sub win2cyg {
	my $win = shift;
	#debug "WIN: '$win'";

	my $drive;
	{
		$win =~ /(\w):\\/;
		if ($1) {
			$drive = $1;
		} else {
			die "win2cyg: Drive not recognized!";
		}
	}

	my $path = ( split /:\\/, $win )[-1];
	$path =~ tr,\\,/,;
	my $cyg = "/cygdrive/$drive/$path";
	#debug "CYG: $cyg!";
	return $cyg;

}