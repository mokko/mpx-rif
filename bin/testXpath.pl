#!/usr/bin/perl

use strict;
use warnings;
use XML::LibXML;
use XML::LibXSLT;
sub debug;
my $fn = '/home/Mengel/projects/mpx-rif/lastharvest.mpx';

if ( !-f $fn ) {
	die "File not found: $fn";
}

debug "Load harvest ...";

my $parser = XML::LibXML->new();
my $doc    = $parser->parse_file($fn);

my $xpc = XML::LibXML::XPathContext->new($doc);
$xpc->registerNs( 'mpx', 'http://www.mpx.org/mpx' );

debug "Start xpath ...";

my @testCases =(
	'VII c 121 f',    #
	'VII c 121 q',    # should only find one
	'VII c 162 a-h',   # should only find none
	'I C 4143 a',	  # 1
);

foreach my $identNr (@testCases) {

	my $xpath = q(
		mpx:museumPlusExport/mpx:sammlungsobjekt[
			mpx:identNr[
				@art != 'Ident. Unternummer' or not (@art)
			]
	);
	$xpath .= qq(
		= '$identNr'
		]
	);
	$xpath .= q(
		/@objId
	);

	debug "   " . $xpath;

	my @nodes = $xpc->findnodes($xpath);
	debug "   " . scalar @nodes . ' nodes found';

	foreach my $node (@nodes) {

		#debug '  objId: '.$node->findvalue('@objId');
		debug '  objId: ' . $node->string_value;
	}
}

sub debug {
	my $msg = shift;
	print "$msg\n";
}
