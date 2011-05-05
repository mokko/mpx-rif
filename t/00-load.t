#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'MPX::RIF' ) || print "Bail out!
";
}

diag( "Testing MPX::RIF $MPX::RIF::VERSION, Perl $], $^X" );
