package MPX::RIF::Helper;
use strict;
use warnings;
use Exporter;
use Log::Handler;

# ABSTRACT: - For stuff that I want to inherit/ from elsewhere in MPX::RIF
# why export OO stuff?
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(debug error log str2num registerMPX win2cyg);

our $debug = 0;
our $log   = init_log();    #will store the logger object

=head1 SYNOPSIS

	use MPX::RIF::Helper qw(debug log);

	MPX::RIF::Helper::init_log($logfile); #$logfile is optional
	log "blah";

	MPX::RIF::Helper::init_debug(); #activates debug
	debug "blah"

=cut

##
## MESSAGES
##

=func error 'message', $err_code;

prints error message and exits with error code. This is intended for user 
errors.

=cut

sub error {
	my $msg=shift || '';
	my $error_code=shift || 1;
	print "Error: $msg!\n";
	exit $error_code;
}

=head2 debug

If debug is activated during initialization of MPX::RIF, debug outputs messages
to the STDOUT during runtime.

=cut

sub debug {
	my $msg = shift;
	if ( $debug > 0 ) {
		print $msg. "\n";
	}
}

=head2 log

If log is activated during initialization of MPX::RIF, log messages are written
to file during runtime. I use this to store warnings which indicate mapping
problems, missing information or any other failure indicating that the result
is not valid.

=cut

sub log {
	my $msg = shift;
	if ($msg) {

		#debug "$msg";
		$log->warn($msg);
	}
}

=head2 MPX::RIF::Helper::init_debug();

	activates debug messages during runtime on screen

=cut

sub init_debug {
	$debug = 1;
}

=head2 MPX::RIF::Helper::init_log($logfile);

	$logfile is optional. 

=cut

sub init_log {
	my $file    = shift;
	my $default = "mpx-rif.log";

	if ( !$file ) {
		$file = $default;
	}

	$log = Log::Handler->new();

	$log->add(
		file => {
			filename => $file,
			maxlevel => 7,
			minlevel => 0
		}
	);
}

=head2 unlink_log ($logfile);

Deletes logfile, e.g. before init. Returns success on success.

=cut

sub unlink_log {
	my $file    = shift;
	my $default = "mpx-rif.log";

	if ( !$file ) {
		$file = $default;
	}

	debug "delete log file ($file)";

	if ( -f $file ) {

		#debug "about to unlink logfile $file";
		unlink $file or warn "cannot delete old file $!";
		return 1 unless $!;
		return if $!;
	}
	else {
		debug "logfile does not exist so nothing to do $file";
	}

}


##
## XML STUFF
##


=func my $xpc=registerMPX ($doc);

Expects a XML::LibXML document. Returns a XML::LibXML::XPathContext.

=cut

sub registerMPX {
	my $doc = shift;
	my $xpc = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs( 'mpx', 'http://www.mpx.org/mpx' );
	return $xpc;
}

=func my $xpc=registerNS ($doc);
=cut

sub registerNS {
	my $doc = shift;
	my $xpc = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs( 'mpx', 'http://www.mpx.org/mpx' );
	return $xpc;
}


=func my $num=string2num ($string);
	Simple translation of A to 1, B to 2 etc. for strings consisting of multiple letters.
	
	Actually it returns as a string consisting of digits, could be 0101. 
	
=cut

sub str2num {
	my $string=shift or return;
	my $no=0;
	
	#e.g. aa
	for ( my $i = 0 ; $i < length $string ; $i++ ) {
		#m is the position of the digit. The last digit is 1, the 3rd digit is 3
		my $m=(length $string)-$i;		
		#n is the value of the respective digit
		my $n=alpha2num( substr $string, $i, 1 );
		#aa:1*26+1: 26n+n
		#ab:1*26+2: 26n+n
		#bb:2*26+2: 26n+n
		#aaa:26*26*1+26*1+1: 26*26n+26n+n: 26**2n+26**1n+26**0n
		$no=26**($m-1)*$n+$no;
	}
	return $no;
}

sub _str2num {
	my $string=shift or return;
	my $no;
	
	for ( my $i = 0 ; $i < length $string ; $i++ ) {
		$no .=
		  sprintf( "%02d", alpha2num( substr $string, $i, 1 ) );
	}
	return $no;
}

=func my $num=alpha2num ($alpha);
	Simple translation of A to 1, B to 2 etc.
=cut

sub alpha2num {
	my $in = shift || return;

	$in = uc($in);

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

	if ( $in =~ /\d/ ) {
		return $in;
	}

	if ( $tr{$in} ) {
		return $tr{$in};
	}

	warn "alpha2num error $in";
}


#
# FILE PATH STUFF
#

=head2 my $cyg=win2cyg($win);

very simple re-implementation of cygpath.

=cut

sub win2cyg {
	my $win = shift;

	#debug "WIN: '$win'";

	my $drive;
	{
		$win =~ /(\w):\\/;
		if ($1) {
			$drive = $1;
		}
		else {
			die "win2cyg: Drive not recognized!";
		}
	}

	my $path = ( split /:\\/, $win )[-1];
	$path =~ tr,\\,/,;
	my $cyg = "/cygdrive/$drive/$path";

	#debug "CYG: $cyg!";
	return $cyg;

}



1;