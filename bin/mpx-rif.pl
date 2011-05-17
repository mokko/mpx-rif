#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Std;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MPX::RIF;


my $opts = {};
getopts( 'b:ds:t', $opts );

#-s 1 - stop after scandir
#-s 2 - stop after dirparser
#-s 3 - stop after objId lookup
#-b   - begin with 1-scandir.yml

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
	if ($opts->{b} !~/\d/) {
		print "-b parameter not a single digit integer\n";
		exit 1;
	}
	$config->{BEGIN}=$opts->{b};
}

if ( $opts->{d} ) {
	$config->{DEBUG} = 1;
}

if ( $opts->{s} ) {
	if ( $opts->{s} !~ /\d/ ) {
		print "Error: stop parameter is not a single digit integer\n";
		exit 1;
	}
	$config->{STOP} = $opts->{s};
}

if ( $opts->{t} ) {
	$config->{TESTDATA} = 1;
}


#
# MAIN
#

my $faker = MPX::RIF->new($config);
$faker->run();

=head1 NAME

mpx-rif.pl

=head2 SYNOPSIS

mpx-rif.pl -d conf/MIMO.yml

-d debug
-b 1
-s 1
=cut
