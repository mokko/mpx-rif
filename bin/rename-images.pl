#!/usr/bin/perl

use strict;
use warnings;
use File::Find;
use File::Copy;

#add -A if no priority specified in filename

if ( !$ARGV[0] ) {
	print "Error: Need dir to start my work!\n";
}

if ( !-d $ARGV[0] ) {
	print "Error: Input is no dir\n";
}

find( \&wanted, $ARGV[0] );

sub wanted {

	#	 $File::Find::dir
	#	 $_ filename in dir
	#	 $File::Find::name 	complete path/name
	return if $_ eq '.';
	print "test $_\n";

	if ( $_ !~ /\-/ ) {
		my $old=$_;
		$_=~ s/\s?(x?)\s?(\.\w*)$//;
		if ($2) {
			my $new=$_.' -A';
			$new.=' '.$1 if $1; #x if there is an x
			$new.=$2;
			print "->mv '$old' '$new'\n";
			#move ($old, $new);
		}
	}

}
