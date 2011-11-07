#!/usr/bin/perl
# PODNAME: xpath.pl
# ABSTRACT: apply xpath on xml files

use strict;
use warnings;
use XML::LibXML;
use Pod::Usage;
use Getopt::Std;

sub debug;

getopts( 'f:vhn:', my $opts = {} );
pod2usage() if ( $opts->{h} );

=head1 SYNOPSIS

xpath.pl -f file.xml '//xpath'
xpath.pl -n mpx -f file.xml '//mpx:xpath'
xpath.pl -h

I put the xpath expression in single quotes which I expect your shell will 
like. Strictly speaking it's not a matter of this program.

=head2 COMMAND LINE OPTIONS

=over 1

=item -h

help: this text

=item -n

namespace: speficy namespace prefix. Prefix has to be associated with namespace
uri somehwere. Currently inside this file.

=item -v

verbose: be more verbose

=back

=head1 DESCRIPTION

Little tool that applies xpath queries to xml. Let's see how elegant I can make 
this within a few hours.

=head2 TODO

=cut

#todo: this should be in a configuration file
my $namespaces = {
	prefix => 'uri',
	mpx    => 'http://www.mpx.org/mpx',
	lido =>'http://www.lido-schema.org', 
};

$opts->{namespaces} = $namespaces;

commandLineSanity($opts);

my $xpc = initNS($opts);

my $doc = XML::LibXML->load_xml( location => $opts->{f} )
  or die "Problems loading xml from file ($opts->{f})";

debug "Xpath from command line: $ARGV[0]";
my $xpath = XML::LibXML::XPathExpression->new( $ARGV[0] );

#it seems that we don't need that test
#if ( !$xpath ) {
#	print "Error: Can't compile xpath ($ARGV[0])!\n";
#	exit 1;
#}

##
## Do the actual query
##
if ($xpc) {
	contextQuery( $xpc, $xpath, $doc );
}
else {
	query( $doc, $xpath );
}

exit;

#
# SUBs
#

sub contextQuery {
	my $xpc   = shift or die "Need xpc";
	my $xpath = shift or die "Need xpath";
	my $doc   = shift or die "Need doc";

	my $object = $xpc->find( $xpath, $doc );
	output ($object);

}

sub output {
	my $object=shift or die "Need object!";
	debug 'Response object type: ' . ref $object;
	if ( ref $object ne 'XML::LibXML::NodeList' ) {
		print $object;
	}
	else {
		foreach ( $object->get_nodelist() ) {
			print $_->toString(1);
		}
	}
	print "\n";
}

sub query {
	my $xpath = shift or die "Need xpath";
	my $doc   = shift or die "Need doc";

	my $object = $doc->find($xpath);
	output ($object);
}


sub initNS {
	my $opt = shift or die "Need opts!";

	if ( !$opts->{n} ) {
		return;
	}

	my $prefix = $opts->{n};
	my $uri    = $opts->{namespaces}->{$prefix};

	if ( !$uri ) {
		print "Error: namespace prefix not defined!\n";
		exit 1;

	}

	my $xpc = XML::LibXML::XPathContext->new();
	$xpc->registerNs( $prefix, $uri );
	debug "Register namespace $prefix:$uri";

	return $xpc;
}

sub commandLineSanity {
	my $opts = shift or die "Need opts";

	debug "Debug/verbose mode on";

	if ( !$opts->{f} ) {
		print "Error: Need xml file! Specify using -f\n";
		exit;
	}

	if ( !-f $opts->{f} ) {
		print "Error: Input xml file not found!\n";
		exit 1;
	}

	if ( !$ARGV[0] ) {
		print "Error: No xpath specified\n";
		exit 1;
	}

}

sub debug {
	my $msg = shift;
	if ( $opts->{v} ) {
		print ' ' . $msg . "\n";
	}
}
