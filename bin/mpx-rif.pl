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

Executes all steps one after according to configuration.

=head2 DECRIPTION

The steps are
(1) scandir - Read the directory specified in configuration recursively,
filter files of one or several types (extensions), write the resulting 
file list in the resource store, dump the store (containing the file list) 
as yaml (for debugging purposes). 
 
If option -s 1 is specified the MPX::RIF will exit here.

Resource store is dumped as yaml to check if this step was successful.

(2) parsedir - Parse the filepath for information. This is done in an external
module since it is very specific to the project, e.g. different for MIMO than 
for 78s. The result is saved in the resource store and dumped to yaml for 
debugging.

Resource store is dumped as yaml to check if this step was successful.

(3) objIdloopup - To add the metadata of the resource store to existing mpx
data we need to add the right objId to each multimediaObjekt. We look this 
information up in one big xml file which should contain all exported 
Sammlungsobjekte.

Now a harvester is included. Suppress with -n option

Resource store is dumped as yaml to check if this step was successful.

(4) filter - If a resource lacks one of a list of required features, the 
resource is dropped (deleted) form the resource store.

(5) writeXML - The resource store is converted to XML-MPX or more precisely to 
multimediaobjekt-records. 

(6) validate - validate XML and check for duplicate mulId

=cut
