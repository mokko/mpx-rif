#!/usr/bin/perl
use 5.14.0;
use strict;
use warnings;
use Path::Class qw(file dir);
use File::Copy;
use Pod::Usage;
use Getopt::Std;
use FindBin;
use File::Basename 'fileparse';
use File::Find::Rule;
#File::Path::Tiny required only if certain directories are missing

#assuming that this script will reside at bin/MIMO-resmvr.pl and will not be installed via make install
use lib "$FindBin::Bin/../lib";

use MPX::RIF::Helper qw(error debug loadConfig);

getopts( 'dhpv', my $opts = {} );
pod2usage( -verbose => 2 ) if ( $opts->{h} );
MPX::RIF::Helper::init_debug() if ( $opts->{v} or $opts->{d} );
debug "Debug mode on";
my $dir = '/cygdrive/R/MIMO-JPGS_Ready-To-Go';
my $c = 0;    #count files that have actually been moved
my $r = 0;    #count files that are still not found

=head1 SYNOPSIS

doubleCheck.pl -v 

=head1 DESCRIPTION

reads the log file, tries to copy missing resource files (images) from other 
location (R:\ etc.) to this location (M:\)

=cut

error "Can't find $dir" if !-d $dir;
my $config = loadConfig();
my $logfile = file( $config->{tempdir}, $config->{logfile} )->stringify;
debug "Looking for logfile at '$logfile'";

open( my $fh, "<", $logfile ) or error "cannot open < $logfile: $!";
while (<$fh>) {

	#working only on errors of this type...
	my @l = split( /Resource not found:/, $_ );
	next if ( !$l[1] );
	$r++;

	#only where resources are missing on M:\
	if ( $l[1] =~ m!^/cygdrive/M! ) {
		$l[1] =~ s!\s!!g;
		my $mPath    = file( $l[1] );
		my $filename = fileparse($mPath);

		debug "searching for '$filename' somewhere in '$dir'";
		my @file =
		  File::Find::Rule->file()->nonempty->name($filename)->in($dir);

		#did we find any file?
		if ( scalar(@file) > 1 ) {
			warn
			  "There are several files with this name:'$filename' somewhere in "
			  . "$dir. I'll take the first I find";
		}

		if ( $file[0] ) {
			$file[0] = file( $dir, $file[0] );    #make absolute..
			debug $file[0], ' -> ', $mPath;
			if ( !-d $mPath->parent ) {
				debug 'implied dir does not exist, I making it now: '.$mPath->parent;
				require File::Path::Tiny;
				File::Path::Tiny::mk_parent($mPath) or error "Can't make implied dir for '$mPath'";
			}
			copy( $file[0], $mPath ) if ( !$opts->{p} );
			$c++;
		}
	}
}
$r = $r - $c;
say "$c files copied; $r remain missing\n";
