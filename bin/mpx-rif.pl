#!/usr/bin/env perl

# PODNAME: mpx-rif.pl
# ABSTRACT: command line frontend for MPX::RIF

use strict;
use warnings;

use Getopt::Std;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MPX::RIF;
use Pod::Usage;


my $opts = {};
getopts( 'b:dhns:tv', $opts );
pod2usage(-verbose => 2) if ( $opts->{h} );

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

if ( $opts->{d} or $opts->{v} ) {
	$config->{DEBUG} = 1;
}

if ( $opts->{n} ) {
	print "Set NOHARVEST switch\n" if $config->{DEBUG};
	$config->{NOHARVEST} = 1;
}

if ( $opts->{s} ) {
	if ( $opts->{s} !~ /\d/ ) {
		print "Error: stop parameter is not a single digit integer\n";
		exit 1;
	}
	$config->{STOP} = $opts->{s};
}

#used? not documented at the moment
if ( $opts->{t} ) {
	$config->{TESTDATA} = 1;
}


#
# MAIN
#

my $faker = MPX::RIF->new($config);
$faker->run();


=head2 SYNOPSIS

mpx-rif.pl [-d] conf/MIMO.yml
mpx-rif.pl -b 1 -s 1 conf/MIMO.yml

=head2 OPTIONS

-d: prints debug info to STDOUT

-b 1: begins at step 1

-s 1: stop after step 1

-n: no harvest

=cut
