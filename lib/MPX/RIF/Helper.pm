package MPX::RIF::Helper;
{
  $MPX::RIF::Helper::VERSION = '0.021';
}

# ABSTRACT: - For stuff that I want to inherit from elsewhere in MPX::RIF

use Exporter;
use Log::Handler;

@ISA       = qw(Exporter);
@EXPORT_OK = qw(debug log);

our $debug = 0;
our $log   = init_log();    #will store the logger object


sub debug {
	my $msg = shift;
	if ( $debug > 0 ) {
		print $msg. "\n";
	}
}


sub log {
	my $msg = shift;
	if ($msg) {

		#debug "$msg";
		$log->warn($msg);
	}
}


sub init_debug {
	$debug = 1;
}


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
1;
__END__
=pod

=head1 NAME

MPX::RIF::Helper - - For stuff that I want to inherit from elsewhere in MPX::RIF

=head1 VERSION

version 0.021

=head1 SYNOPSIS

	use MPX::RIF::Helper qw(debug log);

	MPX::RIF::Helper::init_log($logfile); #$logfile is optional
	log "blah";

	MPX::RIF::Helper::init_debug(); #activates debug
	debug "blah"

=head2 debug

If debug is activated during initialization of MPX::RIF, debug outputs messages
to the STDOUT during runtime.

=head2 log

If log is activated during initialization of MPX::RIF, log messages are written
to file during runtime. I use this to store warnings which indicate mapping
problems, missing information or any other failure indicating that the result
is not valid.

=head2 MPX::RIF::Helper::init_debug();

	activates debug messages during runtime on screen

=head2 MPX::RIF::Helper::init_log($logfile);

	$logfile is optional. 

=head2 unlink_log ($logfile);

Deletes logfile, e.g. before init. Returns success on success.

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

