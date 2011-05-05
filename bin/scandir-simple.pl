#!/usr/bin/perl
use warnings;
use strict;
use YAML::Syck qw/LoadFile DumpFile/;
use Carp qw/croak carp/;
use File::Find::Rule;

if ( !$ARGV[0] ) {
	print "Error: No input dir specified";
	exit 1;
}

if ( !-d $ARGV[0] ) {
	print "Error: Input is no directory";
	exit 1;
}

print "Begin scanning $ARGV[0]\n";

my $data = {};
foreach my $file ( File::Find::Rule->file()->in( $ARGV[0] ) ) {
	print "  $file ";
	$data->{$file} = {};
}

my $output = '1-scandir.yml';
print "About to write output ($output)";

DumpFile( $output, $data );
