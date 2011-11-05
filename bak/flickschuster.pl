#!/usr/bin/env perl
print "program not complete";
exit 1;
# PODNAME: Flickschuster.pl
# ABSTRACT: fix resource filenames to match IdentNr in latestharvest.mpx

use strict;
use warnings;
use Getopt::Std;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MPX::RIF;
use Pod::Usage;

use Data::Dumper qw(Dumper);

sub debug;

getopts( 'dhvx', my $opts = {} );
pod2usage( -verbose => 2 ) if ( $opts->{h} );

=head1 SYNOPSIS

flickschuster.pl -v -x conf/cong.yml

-h help
-v verbose (same as -d debug messages)
-x do-it-mode: do actual renaming instead of just report what would be renamed

...currently it looks that I don't need the conf/conf.yml

=cut

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

if ( $opts->{x} ) {
	debug "Do-it-mode. File will actually be moved!";
}
else {
	debug "Planning mode. No file will actually be moved!";
}

if ( !$ARGV[0] ) {
	print "Error: Need a config file!\n";
	exit 1;
}

if ( !-f $ARGV[0] ) {
	print "Error: Config file not found!\n";
	exit 1;
}

#
# MAIN
#
my $config = { CONFIG => $ARGV[0] };

if ( $opts->{d} or $opts->{v} ) {
	$config->{DEBUG} = 1;
}

my $faker = MPX::RIF->new($config);
$faker->flickschuster();


sub debug {
	my $msg = shift;
	if ( $opts->{d} > 0 ) {
		print $msg. "\n";
	}
}
