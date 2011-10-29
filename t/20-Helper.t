#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>2;
use FindBin;
use lib "$FindBin::Bin/../lib";

require_ok('MPX::RIF::Helper');
use MPX::RIF::Helper qw(debug log);

my $testlog='test.log';

if (-f $testlog) {
	unlink $testlog or die "Can't delete $testlog";
}

MPX::RIF::Helper::init_log ($testlog);

ok(-f $testlog == 1, 'log file created?' );

log 'blah';