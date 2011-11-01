package MPX::RIF::Resource;
{
  $MPX::RIF::Resource::VERSION = '0.021';
}
# ABSTRACT: deal with resources and features
use Carp qw/carp croak/;
use strict;
use warnings;
use MPX::RIF::Helper qw(debug log);
MPX::RIF::Helper::init_log ();


sub new {
	my $class    = shift;
	my $resource = {};
	my %opts     = @_;

	bless $resource, $class;

	if (%opts) {
		$resource->addFeatures(%opts);
	}

	#debug "MIMO: $resource". ref $resource;
	return $resource;
}


sub addFeatures {
	my $resource = shift;

	#i have to make sure that caller has always right number of
	#paramters!
	my %opts = @_;

	if (%opts) {
		foreach my $key (%opts) {

			#i dont understand why there can be uninitilized $keys
			if ( $key && $opts{$key} ) {

				#debug "OSWEGO $key:".$opts{$key};
				$resource->{$key} = $opts{$key};
			}
		}
	}
}


sub addConstants {
	my $resource = shift;
	my $consts   = shift;

	if ( !$consts ) {
		croak "addConstants called without constants";
	}

	my %constants = %{$consts};

	foreach my $feature ( keys %constants ) {
		my $value = $constants{$feature};
		if ( $feature && $value ) {
			$resource->addFeatures( $feature => $value );
		}
	}
}


sub get {
	my $resource = shift;
	my $feature  = shift;

	if ( !$feature ) {
		croak "$resource->get called without a feature";
		return ();
	}

	#this is no error, just return empty
	if ( !$resource->{$feature} ) {
		return ();

		#carp "$resource->get called on non existant feature";
	}

	return $resource->{$feature};
}


sub loopFeatures {
	my $resource = shift;

	#sort alphabetically
	return sort keys %{$resource};

}


sub path2mpx {
	my $resource = shift;    #function or method?
	my $feat     = shift;

	if ( !$feat ) {
		croak "No feat!";
	}

	my $path = $resource->get($feat);
	if ( !$path ) {
		croak "No feature with name $feat!";
	}
	#delete $resource->{$feat};

	#I will likely have cygpaths, so I need some kind of conversion
	$path = cygpath($path);
	#debug "path2mpx: $path";

	#i wonder if I should do it alone or if I should use a module
	#like File::Basename or File::Spec

	$path =~ /(\S):\\([\S |\\]+)\\(\S+)\.(\S+)/;

	if ( $1 && $2 && $3 && $4 ) {
		debug "split: $1:\\$2 -X- $3 -X- $4";
		$resource->addFeatures(
			multimediaPfadangabe  => "$1:\\$2",
			multimediaDateiname   => $3,
			multimediaErweiterung => $4,
		);
	}

	#$full_path = "$pfad\\$name.$erweiterung";
	#multimediaPfadangabe
	#multimediaDateiname
	#multimediaErweiterung
}


sub rmFeat {
	my $resource = shift;    #function or method?
	my $feat     = shift;

	if ($resource->{$feat}) {
		delete $resource->{$feat};
	} else {
		return ();
	}
}


sub cygpath {
	my $nix_path = shift;

	#should I check if path is unix path? Could be difficult
	if ($nix_path) {
		my $win_path = `cygpath -wa '$nix_path'`;
		$win_path =~ s/\s+$//;
		return $win_path;

	} else {

		#catches error which breaks execution
		warn "Warning: cygpath called without param";
	}
}

1;

__END__
=pod

=head1 NAME

MPX::RIF::Resource - deal with resources and features

=head1 VERSION

version 0.021

=head1 SYNOPSIS

my $resource=MPX::RIF::Resource->new(id=>$path);

=head2 my $resource=MPX::RIF::Resource->new(id=>$path);

Parameters are optional, see $resource->addFeatures.

=head2 $resource->addFeatures(key=>value);

You need to have an id at some point,
but it's your own obligation to take care of it.
Additional value pairs are fine:
	MPX::RIF::Resource->new(
		id=>$path,
		key1=>$value1,
		key2=>$value2,
	);

=head2 $resource->addConstants ($self->{constants});

constants is a hashref with key value pairs

$constants={
	$key1=>$value1,
	$key2=>$value2,
}

They will be added to the resource.

=head2 my $value=$resource->get('feature');

getter that returns the value for a specified feature.
If feature doesn't return, getter returns nothing. So you can use it to
test if feature exists.

=head2 my @arr=$resource->loopFeatures;

Getter that returns features for a given resource as array:

	foreach my $feat ($resource->loopFeature) {
		my $value=$resource->get($feat);
	}

=head2 $resource->path2mpx ('id');
	$resource->path2mpx ('id');

	Assumes that id has path.


	not used any more!

=head2 $resource->rmFeat ($feat);

Delete a feature, expects feature name.

=head2 my $winpath=cygpath($nixPath);

Quick and very dirty.

=head1 NAME

MPX::RIF::Resource

...hide the dirty work with the $data hashref in the resource object.

For use inside MPX::RIF. MPX::RIF's end user shouldn't need this.

Of course, a resource is not a resource, but its description. A resource is
identified by a unique id (usually a filepath). Each resource has a number
of arbitrary features. I will use this data model as long as I can and modify
if it's not enough anymore.

$resource= {
	id=>'/path/to/resource/on/disk.bla',
	identNr=>'VII c 123a',
	feature=>'value'
}

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

