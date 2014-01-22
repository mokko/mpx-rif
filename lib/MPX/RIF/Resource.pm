package MPX::RIF::Resource;

# ABSTRACT: deal with resources and features
use Carp qw/croak/;
use strict;
use warnings;
#use MPX::RIF::Helper qw(debug log str2num);
#MPX::RIF::Helper::init_log();

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

=head1 SYNOPSIS

my $resource=MPX::RIF::Resource->new(id=>$path);

=head2 my $resource=MPX::RIF::Resource->new(id=>$path);

Parameters are optional, see $resource->addFeatures.

=cut

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

=head2 $resource->addFeatures(key=>value);

You need to have an id at some point,
but it's your own obligation to take care of it.
Additional value pairs are fine:
	MPX::RIF::Resource->new(
		id=>$path,
		key1=>$value1,
		key2=>$value2,
	);

=cut

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

=head2  $resource->addConstants ($self->{constants});

constants is a hashref with key value pairs

$constants={
	$key1=>$value1,
	$key2=>$value2,
}

They will be added to the resource.

=cut

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

=head2 my $value=$resource->get('feature');

getter that returns the value for a specified feature.
If feature doesn't return, getter returns nothing. So you can use it to
test if feature exists.

=cut

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

=head2 my @arr=$resource->loopFeatures;

Getter that returns features for a given resource as array:

	foreach my $feat ($resource->loopFeature) {
		my $value=$resource->get($feat);
	}

=cut

sub loopFeatures {
	my $resource = shift;

	#sort alphabetically
	return sort keys %{$resource};

}

=head2 $resource->path2mpx ('id');
	$resource->path2mpx ('id');

	Assumes that id has path.


	not used any more!



=cut

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

=head2 $resource->rmFeat ($feat);

Delete a feature, expects feature name.

=cut

sub rmFeat {
	my $resource = shift;    #function or method?
	my $feat     = shift;

	if ( $resource->{$feat} ) {
		delete $resource->{$feat};
	}
	else {
		return ();
	}
}

=func my $winpath=cygpath($nixPath);

Quick and very dirty. 

Seems we have too many different cygpath functions around here.

=cut

sub cygpath {
	my $nix_path = shift or return;

	#should I check if path is unix path? Could be difficult
		my $win_path = `cygpath -wa '$nix_path'`;
		$win_path =~ s/\s+$//;
		return $win_path;
}

1;
