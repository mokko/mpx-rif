#!/usr/bin/perl 

use strict;
use warnings;

use FindBin;
use File::Spec;

use lib File::Spec->catfile( $FindBin::Bin, '..', 'lib' );
use MPX::RIF;
use Test::More;

my %cases = (

	#normal I A
'/cygdrive/R/MIMO-JPGS_Ready-To-Go/farbig/Andreas_Richter/I A 1463 a -A x.jpg'
	  => 'I A 1463 a',

	#Nls <x>
'/cygdrive/R/MIMO-JPGS_Ready-To-Go/farbig/Verena_Höhn/VII Nls 62 _2_ -A x.jpg'
	  => 'VII Nls 62 <2>',

	#VII {nnnn} a,b
'/cygdrive/R/MIMO-JPGS_Ready-To-Go/farbig/Svenja_Strauss/VII c 731 a,b -A x.jpg'
	  => 'VII c 731 a,b',

	#... a-za
	'/cygdrive/R/MIMO-JPGS_Ready-To-Go/s_w/D. Graf/VII c 121 a-za -A x.jpg' =>
	  'VII c 121 a-za',

);


my $dir = File::Spec->catfile( $FindBin::Bin, 'tdata' );

if ( !-d $dir ) {
	plan skip_all => 'tdata not available';
} else {
	plan tests => scalar( keys %cases );
}

my $config = {
	CONFIG => File::Spec->catfile( $dir, 'config.yml' ),

	#	DEBUG  => 1,
};

my $faker = new MPX::RIF($config);

#loadStore
$faker->_loadStore( File::Spec->catfile( $dir, $MPX::RIF::temp->{1} ) );

#parsedir
$faker->parsedir();

foreach my $id ( keys %cases ) {
	my $expected = $cases{$id};
	my $resource = $faker->_getResource($id);
	my $identNr  = $resource->get('identNr');
	ok( $identNr eq $expected, $expected );
}

#start testing

