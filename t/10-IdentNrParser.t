#!/usr/bin/perl 
use strict;
use warnings;
use Test::More;


my %cases = (
	#$got=>$expected,
	'path/to/VII a 123 a -A.jpg' => 'VII a 123 a',
	'path/to/VII a 123 a -A x.jpg' => 'VII a 123 a',
	'VII a 123 a.jpg' => 'VII a 123 a',
);

my %isnt=(
	'VII a 123 a.jpg' => 'VII a 123',
);

plan tests => 2 + scalar (keys %cases) + scalar (keys %isnt);
use FindBin;
use lib "$FindBin::Bin/../lib";
require_ok('MPX::RIF::Resource');
require_ok('MPX::RIF::MIMO');
MPX::RIF::Helper::init_log();


foreach my $path ( keys %cases ) {

	# ok($got eq $expected, $test_name);
	my $resource = MPX::RIF::Resource->new( id => $path );
	$resource=MPX::RIF::MIMO::parsedir ($resource);
	my $identNr = $resource->get('identNr');
	if ($identNr) {
		is( $identNr, $cases{$path}, "is $path->$cases{$path}" );
	}
}

foreach my $path ( keys %isnt ) {

	# ok($got eq $expected, $test_name);
	my $resource = MPX::RIF::Resource->new( id => $path );
	$resource=MPX::RIF::MIMO::parsedir ($resource);
	my $identNr = $resource->get('identNr');
	if ($identNr) {
		isnt( $identNr, $isnt{$path}, "not $path->$isnt{$path}" );
	}
}

