package MPX::RIF;

use warnings;
use strict;
use YAML::Syck qw/LoadFile DumpFile/;
use Carp qw/croak carp/;
use File::Find::Rule;

use XML::Writer;

our $debug = 0;
sub debug;

=head1 NAME

MPX::RIF - The great new MPX::RIF!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Read a yaml config file, parse a directory, extract information from filepath
write it in human-readable format for debugging and write MPX Mulitmediaobjekt
information (XML).

    use MPX::RIF;

    my $faker = MPX::RIF->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new {
	my $class = shift;
	my $opts  = shift;

	if ( !$opts ) {
		croak "Internal Error: No options!";
	}
	my $self = _loadConfig($opts);
	bless $self, $class;

	#map the module options into the faker object
	$self->_addCLI($opts);

	#check if config makes sense
	$self->_config_consistency();

	return $self;
}

=head2 function2

=cut

sub debug {
	my $msg = shift;
	if ( $debug > 0 ) {
		print $msg. "\n";
	}
}

sub lookupObjId {
	my $self = shift;

}

sub parsedir {
	my $self = shift;

	debug "parse dir ...";

	foreach my $path ( keys( %{ $self->{data} } ) ) {
		no strict 'refs';
		$self->{data}->{$path} = $self->{dirparser}($path);

		if ( $self->{constants} ) {
			my %constants = %{ $self->{constants} };
			foreach my $key ( keys %constants ) {
				$self->{data}->{$path}->{$key} = $constants{key};
			}
		}

	}

	if ( $self->{STOP} == 2 ) {
		DumpFile( '2-parsedir.yml', $self->{data} );
		$self->stop;
	}
}

sub run {
	my $self = shift;

	#data is in $self->{data}

	#STEP 1:- SCANDIR
	if ( !$self->{BEGINWITHSCANDIRYML} ) {
		$self->scandir;    #read a dir recursively
	} else {
		my $data = LoadFile('scandir.yml') or die "Cannot load scandir.yml!";
		if ( !$data ) {
			print "Error: scandir.yml read, but no data!";
			exit 1;
		}

		$self->{$data} = $data;
	}

	#STEP2 - PARSEDIR
	$self->parsedir;       #parse filepaths with external parser
	$self->lookupObjId;

	print "run\n";
}

sub scandir {
	my $self = shift;
	my @name = ['*'];

	if ( $self->{filter} ) {
		@name = $self->{filter};
	}

	debug "scan dir ...";

	foreach
	  my $file ( File::Find::Rule->file()->name(@name)->in( $self->{scandir} ) )
	{

		#debug "   $file";
		$self->{data}->{$file} = {};
	}

	if ( $self->{STOP} == 1 ) {
		DumpFile( '1-scandir.yml', $self->{data} );
		$self->stop;
	}
}

sub stop {
	my $self = shift;
	debug "Exit here since stop parameter is given";
	exit 0

}

sub testparser {
	my $filepath = shift;
	my $item     = {
		ok     => 'alles klar',
		consti => 'konstant',
	};
	return $item;
}

#
# internal interface
#

sub _addCLI {
	my $self = shift;
	my $opts = shift;

	if ( $opts->{VERBOSE} ) {
		$self->{VERBOSE} = $opts->{VERBOSE};
	}

	if ( $opts->{DEBUG} ) {
		$debug = 1;
	}

	foreach (qw/START STOP/) {
		if ( $opts->{$_} ) {
			$self->{$_} = $opts->{$_};
		} else {
			$self->{$_} = 0;
		}
	}
}

sub _config_consistency {
	my $self = shift;

	debug "Enter _config_consistency\n";

	#foreach ( keys %{$self} ) {
	#	debug "$_\n   $self->{$_}";
	#}

	my @mandatory = qw/scandir dirparser/;

	my $err = 0;
	foreach my $item (@mandatory) {
		if ( !$self->{$item} ) {
			print "Configuration problem: Mandatory item $item missing in "
			  . "config file\n";
			$err++;
		}
	}
	if ( $err > 0 ) {
		print "Exit here due to configuration problems\n";
		exit 1;
	}

	#specific tests
	if ( !-e $self->{scandir} ) {
		print "Error: Specified scandir does not exit ($self->{scandir})\n";
		exit 1;
	}

	if ( !-d $self->{scandir} ) {
		print "Error: Scandir is no directory\n";
		exit 1;
	}

	#
	# load the extensions
	#

	if ( ! -f $self->{callbackPath} ) {
		print "Error: Extensions file not found $self->{callbackPath}\n";
		exit 1;
	}
	eval { require $self->{callbackPath} };

	no strict 'refs';
	if ( !defined $self->{dirparser}() ) {
		print "Error: Dirparser callback function not found!\n";
		exit 1;
	}
}

sub _loadConfig {
	my $opts = shift;

	#load config file into the faker object
	if ( !$opts->{CONFIG} ) {
		croak "Internal Error: CONFIG not specified!";
	}

	if ( !-f $opts->{CONFIG} ) {
		croak "Internal Error: config file not found!";
	}

	return LoadFile( $opts->{CONFIG} );
}

=head1 AUTHOR

Maurice Mengel, C<< <mauricemengel at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mpx-rif at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MPX-RIF>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MPX::RIF


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MPX-RIF>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MPX-RIF>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MPX-RIF>

=item * Search CPAN

L<http://search.cpan.org/dist/MPX-RIF/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Maurice Mengel.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of MPX::RIF
