package MPX::RIF::MIMO;

use strict;
use warnings;
use FindBin;
use File::Spec;
use UTF8;
use Carp qw/carp croak/;

#use lib "$FindBin::Bin/../../lib"; #?
use MPX::RIF::Helper qw(debug log);
use MPX::RIF::Resource;
use Encode qw(from_to decode);

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

	# I have some intransparent issues with Umlaute, a unicode problem
	# 1) read file names from disk.
	#    I imagine that perl gets it correctly
	# 2) write it to YML
	#    here i have problems already
	# 3) process it here
	# 4) output it

	#debug "path:$path";
	from_to( $path, 'UTF-8', 'cp1252' );

	#debug here should be incorrect!
	#debug " unicode incorrect? path:$path";
	#if I have to do this, I should better be doing it when I initially

	if ( !$path ) {
		croak "Internal error: resource has no id/path\n";
	}

	debug "+parsedir $path\n";

	my ( $volume, $directories, $file ) = File::Spec->splitpath($path);

	#files
	$file =~ /\.(\w+)$/;
	if ($1) {

		my $erweiterung = $1;
		my $dateiname   = $file;
		$dateiname =~ s/\.$erweiterung//;
		$resource->addFeatures( multimediaPfadangabe => cyg2win($directories) );
		$resource->addFeatures( multimediaDateiname  => $dateiname );
		$resource->addFeatures( multimediaErweiterung => $erweiterung );
	}

	if ( !$file ) {
		carp "+Error: parsedir cannot find file in $path\n";
		exit 1;
	}

	if ( !$directories ) {
		log "+: parsedir cannot find file in $path\n";
	}

	#identNr
	my $identNr = identNr($file);
	if ($identNr) {
		$resource->addFeatures( identNr => $identNr );
	}

	#fotograph(=urheber)
	my $urheber = urheber($directories);
	if ($urheber) {
		$resource->addFeatures( multimediaUrhebFotograf => $urheber );
	}

	#farbe
	my $farbe = farbe($directories);
	if ($farbe) {
		$resource->addFeatures( multimediaFarbe => $farbe );
	}

	#pref
	my $pref = pref($file);
	if ($pref) {
		$resource->addFeatures( 'pref' => $pref );
	}

	#freigabe
	my $freigabe = freigabe($file);
	if ($freigabe) {
		$resource->addFeatures( freigabe => $freigabe );
	}

	#mulId ($resource); at this time we don't have the verknüpftesObjekt yet

	return $resource;
}

=head2 my $identNr=identNr($file);

=cut

sub identNr {
	my $file = shift;

	$file =~ /(VII|I|III)[_|\s]
	       ([a-f]|nls|[a-f] nls)[_|\s]
	       (\d+)[_|\s|\.|\-\w|]
	       ([a-z]-[b-z]|[a-z],[b-z]|[a-z]+[b-z]|[a-h]|)/xi;

	#three parts are required
	if ( !( $1 && $2 && $3 ) ) {
		log " +identNr: Cannot identify $file";
	} else {
		my $identNr = uc($1) . ' ' . $2 . ' ' . $3;
		$identNr .= ' ' . $4 if $4;
		debug " +identNr: $identNr";
		return $identNr;

	}
	return ();    #otherwise might return 1 for success
}

=head2 my $urheber=fotograf($dirs);

=cut

sub urheber {
	my $dirs = shift;

	my @dirs = File::Spec->splitdir($dirs);

	#@dirs=split(/\\/, $dirs);

	my $urheber = $dirs[-2];

	if ( !$urheber ) {

		#a log message yes, but no debug because obviouls from context
		log " +no fotograf found ($dirs)!";
		return ();
	}

	$urheber =~ s!_! !g;

	debug " +fotograf: $urheber";
	return $urheber;
}

=head2 my $farbe=farbe($directories);

=cut

sub farbe {
	my $dirs = shift;
	my @dirs = File::Spec->splitdir($dirs);

	my $farbe = $dirs[-3];

	if ( !$farbe ) {

		log " +no farbe found ($dirs)!";
		return ();
	}

	#$farbe =~ s/_/ /g;

	debug " +farbe: $farbe";
	return $farbe;

}

sub pref {
	my $file = shift;
	my $pref;

	if ( $file =~ /-([A-Z]).*\.\w+$/ ) {
		$pref = $1;

		#debug "letter: $1";
		$pref = alpha2num($pref);
		debug " +pref $pref";
		if ( $pref !~ /\d+/ ) {
			my $msg = "pref is not numeric '$pref' ($file)";
			log $msg;
			debug $msg;
		}
		return $pref;
	}

	log "no priortität! Assume 1 ($file)";
	return 1;
}

sub freigabe {
	my $file = shift;

	if ( $file =~ / x\.\w+$/ ) {
		debug " +freigabe";
		return "web";
	}
}

=head2 my $winpath=cygpath($nixPath);

Quick,dirty and VERY slow.

=cut

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

=head2 my $winpath=cyg2win($nixPath);

Quick, dirty and fast!

I eliminate trailing slash.

=cut

sub cyg2win {
	my $nix = shift;

	$nix =~ m!^/cygdrive/(\w+)/(.*)[/|]!;
	my $drive = $1 if $1;
	my $path  = $2 if $2;
	if ( $path && $drive ) {
		$path =~ s!/!\\!g;
		my $win = "$drive:\\$path";

		#debug "cyg2win-nix: $nix";
		debug "cyg2win: $win";
		return $win;
	}
}

sub alpha2num {
	my $in=shift;

	my %tr = (
		A => 1,
		B => 2,
		C => 3,
		D => 4,
		E => 5,
		F => 6,
		G => 7,
		H => 8,
		I => 9,
		J => 10,
		K => 11,
		L => 12,
		M => 13,
		N => 14,
		O => 15,
		P => 16,
		Q => 17,
		R => 18,
		S => 19,
		T => 20,
		U => 21,
		V => 22,
		W => 23,
		X => 24,
		Y => 25,
		Z => 26,
	);

	if ( $tr{$in} ) {
		return $tr{$in};
	}
}

1;
