#ABSTRACT: write a new harvest to disk

use Moops;
use Carp 'verbose';

=head1 SYNOPSIS

	my $h=MPX::Harvester->new(dataProvider=>$URL,$outputFile=>$file);
    my $response=$h->harvest();
	   $h->harvest2file(); #writes to outputFile
    
    #work with responses
    $h->unwrapAndWrite($response);
	$h->unwrap(response=>$response);
	

=cut

class MPX::Harvester {
	use MPX::RIF::Helper qw(debug log);
	use $FindBin::Bin;
	use XML::LibXSLT;

	has dataProvider   => ( is => 'ro', isa => Str, required => 1 );
	has outputFile     => ( is => 'ro', isa => Str, required => 1 );
	has set            => ( is => 'ro', isa => Str, default  => 'MIMO' );
	has metadataPrefix => ( is => 'ro', isa => Str, default  => 'mpx' );
	has debug          => ( is => 'ro', isa => Bool );
	has unwrapXSL      => (
		is      => 'ro',
		isa     => Str,
		default => sub { file( $FindBin::Bin, '..', 'xsl', 'unwrap.xsl' ) }
	);

	method BUILD {
		MPX::RIF::Helper::init_debug()
		  if $self->debug;

		#config sanity
		if ( !-f $self->unwrapXSL ) {
			die "$unwrapXSL not found at " . $self->unwrapXSL;
		}
	}

	method harvest {

		#use assert
		#debug "About to query data provider: $self->{dataProvider}";

		my $harvester =
		  HTTP::OAI::Harvester->new( baseURL => $self->{dataProvider}, );

		my %args = ( metadataPrefix => $self->metadataPrefix, );
		$args{set} = $self->set if $self->set;
		my $response = $harvester->ListRecords(%args);

		if ( $response->is_error ) {
			warn( "Error harvesting: " . $response->message . "\n" );
		}

		while ( my $rt = $response->resumptionToken ) {
			debug 'harvesting ' . $rt->resumptionToken;
			$response->resume( resumptionToken => $rt );
			if ( $response->is_error ) {
				warn( "Error resuming: " . $response->message . "\n" );
			}
		}

		return $response;
	}

	#$big is a response or a ref to a response?
	method unwrapAndWrite($big) {

		#my $mpx_fn = shift or die "Error!";
		#my $big    = shift or die "Error!";    # scalar ref to response
		debug "Start unwrapping...";
		  
		  ${$big} = $self->unwrap( ${$big}->toDOM );
		  debug "About to write harvest to $mpx_fn";
		  ${$big}->toFile( $self->outputFile, 0 );
		  debug 'Written to file ', $self->outputFile;

	};

	method unwrap($dom) {

		my $xslt        = XML::LibXSLT->new();
		  my $style_doc = XML::LibXML->load_xml(
			location => $self->unwrapXSL,
			no_cdata => 1
		  );

		  my $stylesheet = $xslt->parse_stylesheet($style_doc);

		  #now dom
		  return $stylesheet->transform($dom);
	  }

}
