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
use Carp qw(croak);

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

##
## MAIN
##

commandLineSanity($opts);

#use App::Xpath qw(debug);
#my $app= App::Xpath ($opts)
#$app->initNS();
#$app->query($doc, $xpath)

my $doc = XML::LibXML->load_xml( location => $opts->{f} )
  or die "Problems loading xml from file ($opts->{f})";
my $xpath = prepareXpath($opts);
my $xpc   = initNS($opts);
query( $doc, $xpath, $xpc );

exit 0;

##
## SUBs
##

=func my $xpath=prepareXpath ($opts);

Expects hashref, returns compiled xpath expression. Dies on compile errors.

=cut

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

=func query ($doc, $xpath, $xpc);

Expects LibXML document, an xpath expression (precompiled or as string) and 
optionally xpathContextObject (carrying the info on a registered namespace).

Feeds return value to  function output().

TODO: test for xpath object.

=cut

sub query {
	my $doc   = shift or die "Need doc";
	my $xpath = shift or die "Need xpath";
	my $xpc   = shift;

	if ( ref $doc ne 'XML::LibXML::Document' ) {
		carp("Error: doc is not XML::LibXML::Document");
	}

	if ( ref $xpc eq 'XML::LibXML::XPathContext' ) {
		output( $xpc->find( $xpath, $doc ) );
		return;
	}
	output( $doc->find($xpath) );
	return;
}

=func output ($object);

Expects a LibXML obkject. Prints to STDOUT. Returns empty if no result.

=cut

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

=func my $xpc=initNS($opts);

Expects hashref. Register namespace. If no prefix/uri pair is found, returns empty. 

=cut

sub initNS {
	my $opt = shift or die "Need opts!";
	my $prefix;
	my $uri;

	#prefix either comes from command line or from yml-config
	if ( $opts->{n} ) {
		$prefix = $opts->{n};
	}

	if ( $opts->{s} ) {
		my $queryname = $opts->{s};
		$prefix = $opts->{config}->{savedqueries}->{$queryname}->{ns};
	}

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

=func commandLineSanity ($opts);

Expects a hashref. Die on failure. Rewrite $opts as needed.

Process options and arguments. 

=cut

sub commandLineSanity {
	my $opts = shift or die "Need opts";
	my $file = File::Spec->catfile( $ENV{HOME}, '.xpathrc.yml' );
	debug "Debug/verbose mode on";
	debug "Looking for config in file:$file";

	if ( -f $file ) {
		$opts->{config} = LoadFile($file);
		debug "Config file loaded";
	}

	if ( !$opts->{f} ) {
		print "Error: Need xml file! Specify using -f\n";
		exit 1;
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

=func debug "$msg";

print message to standard output.

=cut

sub debug {
	my $msg = shift;
	if ( $opts->{v} ) {
		print ' ' . $msg . "\n";
	}
}
