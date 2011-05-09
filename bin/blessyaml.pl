#!/usr/bin/perl

#this script is a test. It seems that I cant dump a blessed hashref and the
#same way I can an unblessed using YAML.

use strict;
use warnings;
use YAML::Syck qw(DumpFile LoadFile);

my $test={
	a=>'b',
	c=>'d',
};

DumpFile ('A.yml', $test);

bless $test, 'Some::Class';

DumpFile ('B.yml', $test);


my $test2={
	a=>{b=>'c'},
	d=>{e=>'f'},
};

DumpFile ('C.yml', $test2);

$test2={
	a=>$test,
	d=>$test,
};

DumpFile ('D.yml', $test2);
