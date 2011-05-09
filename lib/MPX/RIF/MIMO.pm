package MPX::RIF::MIMO;

use strict;
use warnings;
use FindBin;
use File::Spec;
use Carp qw/carp croak/;

#use lib "$FindBin::Bin/../../lib"; #?
use MPX::RIF::Helper qw(debug log);
use MPX::RIF::Resource;

#not used
our $verbose = 0;

=head1 NAME

MPX::RIF::MIMO

This package contains the logic that extracts info from the filenames.
Parsedir is the only function called from outside. All other functions are
called from parsedir.

=head2 my $obj=parsedir($path);

obj is a hashref. Might become an object in the future


=cut

sub parsedir {
	my $resource = shift;

	if ( !$resource ) {
		croak "Internal error: parsedir called without resource\n";
	}

	#debug "DDDDD:$resource|".ref $resource;

	my $path = $resource->get('id');

	if ( !$path ) {
		croak "Internal error: resource has no id/path\n";
	}

	debug "+parsedir $path\n";

	my ( $volume, $directories, $file ) = File::Spec->splitpath($path);

	if ( !$file ) {
		carp "+Error: parsedir cannot find file in $path\n";
		exit 1;
	}

	if ( !$directories ) {
		log "+: parsedir cannot find file in $path\n";
	}

	#my $identNr=identNr($file);
	my $identNr=testFile($file);
	if ($identNr) {
		$resource->addFeatures( identNr => $identNr );
	}

	my $urheber=fotograf($directories);
	if ($urheber) {
		$resource->addFeatures(
			multimediaUrhebFotograf => $urheber );
	}
	return $resource;
}


sub testFile {
	my $file=shift;
	$file=~/(\d+)/;
	my $no=$1;
	debug "testFile->no:$no";
	return $no;
}

=head2 my $identNr=identNr($file);

=cut

sub identNr {
	my $file = shift;

	$file =~ /(VII|I|III)[_|\s]
	       ([a-f]|nls|[a-f] nls)[_|\s]
	       (\d+)[_|\s|\.|\-\w|]
	       ([a-h]|a,b|ab|a+b|)/xi;

	#three parts are required
	if ( !( $1 && $2 && $3 ) ) {
		log " +identNr: Cannot identify $file";
	} else {
		my $identNr = uc($1) . ' ' . $2 . ' ' . $3;
		debug " +identNr: $identNr\n";
		return $identNr;

	}
	return ();    #otherwise might return 1 for success
}

=head2 my $urheber=fotograf($dirs);

=cut

sub fotograf {
	my $dirs = shift;

	#print "dirs:$dirs\n";
	my @dirs = File::Spec->splitdir($dirs);

	#@dirs=split(/\\/, $dirs);

	my $urheber = $dirs[-1];

	if ( !$urheber ) {

		#a log message yes, but no debug because obviouls from context
		log " +no fotograf found ($dirs)!";
		return ();
	}

	#$urheber=~s/_/ /;
	debug " +fotograf: $urheber\n";
	return $urheber;
}


1;
