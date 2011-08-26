#!/usr/bin/perl
# ABSTRACT: add priority (-A) to file names which have none
# PODNAME: rename-images.pl

use strict;
use warnings;
use File::Find;
use File::Copy;
use Getopt::Std;
use Pod::Usage;

my $opts = {};
getopts( 'hx', $opts );
pod2usage( -verbose => 2 ) if ( $opts->{h} );


if ( !$ARGV[0] ) {
	print "Error: Need dir to start my work!\n";
}

if ( !-d $ARGV[0] ) {
	print "Error: Input is no dir\n";
}

if ($opts->{x}) {
	print "x mode: do the actual moving and not just showing it\n";
} else {
	print "show mode: just show what you would move if you were in -x mode\n";
}

find( \&wanted, $ARGV[0] );

sub wanted {
	#	 $File::Find::dir
	#	 $_ filename in dir
	#	 $File::Find::name 	complete path/name
	return if $_ eq '.';
	#print "test $_\n";

	if ( $_ !~ /\-/ ) {
		my $old = $_;
		$_ =~ s/\s?(x?)\s?(\.\w*)$//;
		if ($2) {
			my $new = $_ . ' -A';
			$new .= ' ' . $1 if $1;    #x if there is an x
			$new .= $2;
			print "->mv '$old' '$new'\n";
			if ( $opts->{x} ) {
				move( $old, $new ) or die "cant move";
			}
		}
	}
}

__END__
=pod

=head1 NAME

rename-images.pl - add priority (-A) to file names which have none

=head1 VERSION

version 0.014

=head1 SYNOPSIS

rename-images.pl -x directory

=head2 Command Line Options

=over 1

=item -h	Usage

=item -x	do the renaming (otherwise just show what you do)

=back

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

