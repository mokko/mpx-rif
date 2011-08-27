package MPX::RIF::MIMO;
# ABSTRACT: MIMO specific logic
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

=head1 DESCRIPTION

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
	my $identNr = identNr( $file, $directories );
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

identNr expects a filename. It will try to extract the identNr from it. On
failure?

Currently we are looking for identNr with 4/5 elements
1) A roman literal from I - VII. Roman literal typically indicates the
   department. Required.
2) A letter, combination of letters or nls (including variants of nls)
   This element typically indicates a broad geographic area within the
   territory the department is responsible for. Or that is number is
   unknown. Required, except in VI.
3) 'Dlg'. Optional.
4) an integer. Required.
5) a letter or combinations of letters typically indicating the parts
   of the object. Optional
6) Sometimes identNrs are not unique and there is nothing you can change
   about that. In this case they are differentiated by <1>, <2> etc.
   Optional

$x =~/a|b/; either a or b
$x =~/a|b|/; either a or b or nothing
$x =~/(A)sep(B)sep(C)sep|(?(D)sep)||(E)||/; ; #now c is optional, right?

=cut

sub identNr {
	my $file = shift;
	my $path = shift;

	$file =~ /
#1st element: VII
			(I|II|III|IV|V|VI|VII)
				[_|\s]
#2nd element: c C Ca (optional)
	     	(?:([A-Za-z]|Ca|nls|[A-Za-z]{1,2} nls)
	       		[_|\s]||)
#3rd element: Dlg (optional)
	     	(?:(Dlg)
	       		[_|\s]||)
#4th element: 1234
	       	(\d+)
				#sep. could also be dot, but has to be there
	       		[_|\s|\.]
#5th element: a
			#non-matching group: (?:regexp)
			(?:
	        ([a-z]-[b-z]|[a-z],[b-z]|[a-z]+[b-z]|[a-z]{1,2})
				#separator only if there is a 4th element
	       		[_|\s|\.]||)
#6th element: <1>
			(\d?)
	       /xi;

	#VALIDATION
	#so far we have been a bit too permissive, now we need to test
	#various conditions and report on failure
	#1) Signaturen mit VI am Anfang haben entweder nls als zweiten Teil oder
	#   keinen zweiten Teil. OK
	#2) zweiter Teil hat immer Grossbuchstaben außer bei VIIer und VIer

	#we always need these parts
	if ( !( $1 && $4 ) ) {
		return identErr( 'not 1 and 4', $file, $path );
	}

	#test existence of 2 where it has to be
	#all except $1='VI' need $2
	if ( $1 ne 'VI' && ( !$2 ) ) {
		return identErr( "identNr parser: 2 not where it should be: ", $file, $path );
	}

	#uppercase for 2
	if ( ( $1 ne 'VII' ) and ( $1 ne 'VI' ) ) {
		if ( $2 !~ /[A-Z]{1,2}/ ) {
			return identErr( "no uppercase for 2 $2", $file, $path );
		}
	}

	#lowercase for 2
	if ( $1 eq 'VII' ) {
		if ( $2 !~ /[a-z]{1,2}/ ) {
			return identErr( "no lowercase for 2 $2", $file, $path );
		}
	}

	#
	# JOINING
	#

	#required VI
	my $identNr = $1;

	#optional a
	if ($2) {
		$identNr .= ' ' . $2;
	}

	#optional Dlg
	if ($3) {
		$identNr .= ' ' . $3;
	}

	#required 1234
	$identNr .= ' ' . $4;

	#optional a-c
	if ($5) {
		$identNr .= ' ' . $5;
	}

	#optional <1>
	if ($6) {
		$identNr .= ' <' . $6 . '>';
	}
	debug " +identNr: '$identNr'";
	return $identNr;
}

=func identErr($msg, $file, $path);

logs and debugs a simple message.

=cut

sub identErr {
	my $msg  = shift;
	my $file = shift;
	my $path = shift;

	$msg =
	    " +identNr: Cannot extract identNr from $file\n"
	  . "   $path\n"
	  . "   $msg";
	log $msg;
	debug $msg;
}

=head2 my $urheber=$urheber($dirs);
	Extracts fotograph/urheber from directories
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

	#wenn noch kein Urheber ermittelt, gib anonym an
	if ($urheber =~/farbig|s_w|MIMO-JPGS_Ready-To-Go/) {
		#debug "AUSOOOOOOOOOOORTIEREN $urheber";
		$urheber= "anonym";
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

	#wenn noch kein Urheber ermittelt, gib anonym an
	if ($farbe !~ /farbig|s_w/) {
		$farbe = $dirs[-2];
		   if ($farbe !~ /farbig|s_w/) {
			return;
		   }
	}

	$farbe =~ s/_/ /g;


	debug " +farbe: $farbe";
	return $farbe;

}

=func my $pref=pref($file);
	Extracts priority from filename.
=cut
sub pref {
	my $file = shift;
	my $pref;

	if ( $file =~ /-([A-Z]).*\.\w+$/ ) {
		$pref = $1;

		#debug " letter : $1 ";
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

=func my $freigabe_str=freigabe ($file);

Parses the file name for -x signalling that it should be released on the web.
Expects filename and returns the string "web". If it doesn't find the signal
it returns empty.

=cut

sub freigabe {
	my $file = shift;

	if ( $file =~ / x\.\w+$/i ) {
		debug " +freigabe 'Web'";
		return "web";
	}
	return;
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

		#debug "cyg2win: $win";
		return $win;
	}
}

=func my $num=alpha2num ($alpha);
	Simple translation of A to 1, B to 2 etc.
=cut
sub alpha2num {
	my $in = shift || return;

	$in=uc($in);
	#debug "ALPHA2NUM: $in";

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

	if ($in =~/\d/) {
		return $in;
	}

	if ( $tr{$in} ) {
		return $tr{$in};
	}

	warn "alpha2num error $in";
}

1;
