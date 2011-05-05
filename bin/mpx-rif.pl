#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Std;
use FindBin;
use lib "$FindBin::Bin/../lib";

use MPX::RIF;

my $opts = {};
getopts( 'bds:', $opts );

#-s 1 - stop after scandir
#-s 2 - stop after dirparser
#-s 3 - stop after objId lookup
#-b   - begin with scandir.yml

#
# command line sanity
#

if ( !$ARGV[0] ) {
	print "Error: Config file not specified\n";
	exit 1;
}

if ( !-f $ARGV[0] ) {
	print "Error: Config file not found\n";
	exit 1;
}

#
# map command line to module config
#

my $config = { CONFIG => $ARGV[0] };

if ( $opts->{b} ) {
	$config->{BEGINWITHSCANDIRYML}=1;
}

if ( $opts->{d} ) {
	$config->{DEBUG} = 1;
}

if ( $opts->{s} ) {
	if ( $opts->{s} !~ /\d/ ) {
		print "Error: stop parameter is not an integer\n";
		exit 1;
	}
	$config->{STOP} = $opts->{s};
}


#
# MAIN
#

my $faker = MPX::RIF->new($config);
$faker->run();

