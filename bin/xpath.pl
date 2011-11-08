#!/usr/bin/perl
# PODNAME: xpath.pl
# ABSTRACT: query xml files via command line xpath

use strict;
use warnings;
use XML::LibXML;
use Pod::Usage;
use Getopt::Std;
use YAML::XS qw(LoadFile);
use File::Spec;

#binmode(STDOUT, ":utf8"); then output in mintty is not scrambled anymore, but files
#created with "xpath.pl ... > test.xml" don't open correctly in xemacs
#I guess it's better to have display scrambled than files

sub debug;

getopts( 'df:hn:s:v', my $opts = {} );
pod2usage() if ( $opts->{h} );

=head1 SYNOPSIS

xpath.pl -f file.xml "//xpath"
xpath.pl -n mpx -f file.xml "//mpx:xpath"
xpath.pl -h

(Quotes are a matter of your shell.)

=head2 COMMAND LINE OPTIONS

=over 1

=item -h help

this text

=item -n string namespace

Provide a prefix. Prefix has to be associated with namespace uri somehwere. 
Currently inside this file. todo.

=item -v verbose - be more verbose

-d is synonymous with -v

=item -s string - use a saved queries

  e.g. -s MIMO

=item -l list saved queries

=back

=head1 DESCRIPTION

Little tool that applies xpath queries to xml. Let's see how elegant I can make 
this within a few hours.

=head2 TODO

=cut

commandLineSanity($opts);

my $xpc = initNS($opts);

my $doc = XML::LibXML->load_xml( location => $opts->{f} )
  or die "Problems loading xml from file ($opts->{f})";

my $xpath = prepareXpath($opts);

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

sub prepareXpath {
	my $opts = shift or die "No opts!";
	my $raw;
	if ( $ARGV[0] ) {
		$raw = $ARGV[0];
		debug "Xpath from command line: $raw";
	}
	else {
		my $queryname = $opts->{s};
		$raw = $opts->{config}->{savedqueries}->{$queryname}->{xpath};
		if ( !$raw ) {
			print "Error: saved xpath not found\n";
			exit 1;
		}
		debug 'Xpath from saved query: ' . $opts->{s} . ':' . $raw;
	}
	return XML::LibXML::XPathExpression->new($raw);
}

sub contextQuery {
	my $xpc   = shift or die "Need xpc";
	my $xpath = shift or die "Need xpath";
	my $doc   = shift or die "Need doc";

	my $object = $xpc->find( $xpath, $doc );
	output($object);

}

sub output {
	my $object = shift;

	if ( !$object ) {
		debug "no results\n";
		return;
	}
	debug 'Response object type: ' . ref $object;
	if ( ref $object ne 'XML::LibXML::NodeList' ) {
		print $object;
	}
	else {
		foreach my $item ( $object->get_nodelist() ) {
			print $item->toString(1) . "\n";
		}
	}
	print "\n";
}

sub query {
	my $xpath = shift or die "Need xpath";
	my $doc   = shift or die "Need doc";

	my $object = $doc->find($xpath);
	output($object);
}

sub initNS {
	my $opt = shift or die "Need opts!";
	my $prefix;
	my $uri;

	#prefix either comes from command line or from yml-config
	if ( $opts->{n} ) {
		my $prefix = $opts->{n};
	}

	if ( $opts->{s} ) {
		my $queryname = $opts->{s};
		$prefix = $opts->{config}->{savedqueries}->{$queryname}->{ns};
	}

	#if no prefix return right away
	if ( !$prefix ) {
		return;
	}

	$uri = $opts->{config}->{namespaces}->{$prefix};

	if ( !$uri ) {
		print "Error: namespace uri not found!\n";
		exit 1;
	}

	my $xpc = XML::LibXML::XPathContext->new();
	$xpc->registerNs( $prefix, $uri );
	debug "Register namespace $prefix:$uri";

	return $xpc;
}

sub commandLineSanity {
	my $opts = shift or die "Need opts";
	my $file = File::Spec->catfile( $ENV{HOME}, '.xpathrc.yml' );
	debug "Debug/verbose mode on";
	debug "Looking for file:$file";

	if ( -f $file ) {
		$opts->{config} = LoadFile($file);
		debug "Config file loaded";
	}

	if ( !$opts->{f} ) {
		print "Error: Need xml file! Specify using -f\n";
		exit;
	}

	if ( !-f $opts->{f} ) {
		print "Error: Input xml file not found!\n";
		exit 1;
	}

	if ( !$ARGV[0] && !$opts->{s} ) {
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
