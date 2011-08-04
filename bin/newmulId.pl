#!/usr/bin/perl
# PODNAME: newmulId.pl
# ABSTRACT: create new mulIds for mume objects
use strict;
use warnings;
use Time::HiRes qw/gettimeofday/;

use Log::Handler;
use XML::LibXML;

use Getopt::Std;
my $opts = {};
getopts( 'd', $opts );

sub debug;


#
# command line sanity
#

if ( !$ARGV[0] ) {
	print "Error: Specify input file!\n";
	exit 1;
}

if ( !-f $ARGV[0] ) {
	print "Error: Input file not found!\n";
	exit 1;
}

if ( !$ARGV[1] ) {
	print "Error: Specify output file!\n";
	exit 1;
}

if ( -f $ARGV[1] ) {
	print "Warning: Output file exists already, will be overwritten!\n";
}

my $debug = 0;
if ( $opts->{d} ) {
	$debug = 1;
}

#
# load input mpx
#

my $parser = XML::LibXML->new();
my $doc    = $parser->parse_file( $ARGV[0] ) or die "Cannot parse mpx";
my $xpc    = registerNS($doc);

#
# change mulId
#
my $xpath = '/mpx:museumPlusExport/mpx:multimediaobjekt/@mulId';
my @nodes = $xpc->findnodes($xpath);
debug 'found ' . scalar @nodes . " nodes";

foreach my $node (@nodes) {

	#TODO
	#not unique, need HiRes
	my ( $sec, $msec ) = gettimeofday;
	my $mulId = $sec. $msec;
	debug $node->getValue() . " -> $mulId";
	$node->setValue($mulId);
}

#
# save document
#

$doc->toFile( $ARGV[1], 0 );

#
# SUBS
#
sub registerNS {
	my $doc = shift;
	my $xpc = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs( 'mpx', 'http://www.mpx.org/mpx' );
	return $xpc;
}

sub debug {
	my $msg = shift;
	if ( $debug > 0 ) {
		print $msg. "\n";
	}
}


__END__
=pod

=head1 NAME

newmulId.pl - create new mulIds for mume objects

=head1 VERSION

version 0.06

=head1 SYNOPSIS

newmulId.pl in.mpx out.mpx

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

