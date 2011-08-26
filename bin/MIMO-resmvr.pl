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
use Pod::Usage;
use Image::Magick;

use Getopt::Std;
getopts( 'c:dhpv', my $opts = {} );
pod2usage( -verbose => 2 ) if ( $opts->{h} );

sub debug;


#
# command line sanity
#

if ( $opts->{v} ) {
	$opts->{d} = 1;
}

if ( !$opts->{d} ) {
	$opts->{d} = 0;
}
debug "Debug mode on";

if ($opts->{p}) {
	debug "Planning mode on. No file will actually be moved!";
}

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

#
# MAIN
#

# INIT MPX from file (either mume.mpx or lastharvest)
my $xpc   = init_mpx( $ARGV[0] );
my $xpath = '/mpx:museumPlusExport/mpx:multimediaobjekt'
  . '[mpx:verknüpftesObjekt and mpx:multimediaPfadangabe]';

my @nodes = $xpc->findnodes($xpath);

debug "xpath: $xpath";
debug 'found ' . scalar @nodes . " nodes";

# LOOP THRU multimediaobjekte in file
foreach my $node (@nodes) {
	my $node = registerNS($node);

	my @arr   = $node->findnodes('@mulId');
	my $mulId = $arr[0]->string_value();

	if ( !$mulId ) {
		die "Error: no mulId";
	}

	#move only those with @freigabe =~ /Web|web/
	my $freigabe=$node->findvalue ('@freigabe');
	if (! ($freigabe && lc($freigabe) eq 'web') ) {
		debug "no freigabe";
		next;
	}
	#debug "freigabe $freigabe";
	#act on the file path that is saved in resource description
	#multimediaDateiname, multimediaErweiterung etc.
	my ( $win_path, $erweiterung ) = getPath($node);
	if ( !$win_path ) {
		my $msg = "Path not complete for mulId $mulId";
		debug $msg;
		log->warning($msg);
		next;
	}

	#to move the file from cygwin we need cyg path
	my $path = win2cyg($win_path);    #convert to nix for cygwin

	#new filename: $tempdir/$mulId.jpg
	my $new = $config->{tempdir} . '/' . $mulId . '.' . lc($erweiterung);
	debug "$path --> $new";

	#test if resource is found, log warning if not
	if ( !-f "$path" ) {
		$log->warning("Resource not found:$path");
	} else {

		#debug 'er' . lc($erweiterung);
		if ( lc($erweiterung) eq 'jpg' ) {
			resizeJpg( $path, $new );
		} else {
			if ( !$opts->{p} ) {
				copy( $path, $new );
			}
		}
	}
}

#
# SUBs
#


sub resizeJpg {
	my $old = shift;
	my $new = shift;

	#debug "Enter resizeJpg";

	if ( !$old ) {
		die "resizeJpg: no file name old!";
	}

	if ( !$new ) {
		die "resizeJpg: no file name new!";
	}

	my $p = new Image::Magick;
	my ( $width, $height, $size, $format ) = $p->Ping($old);

	if ( $width > 800 or $height > 800 ) {
		debug "downsize image";
		$p->Read($old);
		$log->warning("Downsize $old");
		$p->AdaptiveResize( geometry => '800x800' );
		$p->Write($new);
	} else {
		if ( $width < 800 && $height < 800 ) {
			$log->warning("image $old is smaller than 800 px");
		}

		#if size ok just cp to new location
		copy( $old, $new );
	}
}


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


sub loadConfig {
	my $optc = shift;

	#default:conf/$user.yml
	if ( !$ENV{USER} ) {
		$ENV{USER} = 'USER';
		debug "Environment variable 'USER' not defined. Asume USER";
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
		print "Error: Configuration file does not exist ($file)!\n";
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

__END__
=pod

=head1 NAME

MIMO-resmvr.pl - resource mover for MIMO

=head1 VERSION

version 0.014

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

=head1 FUNCTIONS

=head2 resizeJpg ($old, $new);

Expects two file paths: the current location and the new location. It will
check if image is bigger 800 px in either width or length. The new version
will be limited to 800 px.

I assume I already tested if $old exists and get here only if it does.

=head2 my ($path, $erweiterung)=getPath($node);

	returns full paths as saved in MPX, typically
	M:\\bla\bli\blu\file.jpg

	returns it in two parts
	M:\\bla\bli\blu\file
	and jpg

=head2 debug 'message';

print debug messages to STDOUT. A newline is added at the end of every debug
message.

=head2 init_log ($tempdir);

Return value?

=head2 $xpc=init_mpx ('path/to/mpx');

Opens mpx file with LibXML and registers namespace mpx.

=head2 loadConfig ($opts)

If no $opts are specified, loads config values from a yml file. That
file spec is guessed based on user name:
	conf/$user.yml

If $opts is specified, it will not look at that location, but try to load
the conf file directory from that location.

Only subvalues of 'resourceMover' are returned.

=head2 my $xpc=registerNS ($doc);

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

=head2 my $nix=cygpath ($win);

DEPRECATED. Convert path from windows to unix. VERY slow and VERY annoying.
Not used anymore. See win2cyg instead.

=head2 my $cyg=win2cyg($win);

very simple re-implementation of cygpath.

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

