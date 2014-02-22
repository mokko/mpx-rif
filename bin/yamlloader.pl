#!/usr/bin/perl
#ABSTRACT: Little script to load a yaml file to debug yaml problems
use 5.14.0;
use strict;
use warnings;
use YAML 'LoadFile';
use Data::Dumper;

die 'need a parameter' if (!$ARGV[0]);
die 'file doesn\'t exist' unless -f $ARGV[0];

say "Trying to load $ARGV[0]";

my $config = LoadFile($ARGV[0]) or die "Cannot load config file";
say Dumper $config;