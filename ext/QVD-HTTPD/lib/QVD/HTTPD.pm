package QVD::HTTPD;

use warnings;
use strict;

our $VERSION = '0.01';

use URI::Split qw(uri_split);

use QVD::HTTP::StatusCodes qw(:all);

use parent qw(Net::Server);



# token          = 1*<any CHAR except CTLs or separators>
# separators     = "(" | ")" | "<" | ">" | "@"
#                | "," | ";" | ":" | "\" | <">
#                | "/" | "[" | "]" | "?" | "="
#                | "{" | "}" | SP | HT
my $token_re = qr/[!#\$%&'*+\-\.0-9a-zA-Z]+/;

sub process_request {
    my $self = shift;
    while (<>) {
	s/\r?\n$//; # HTTP chomp
	next if /^\s*$/;
	if (my ($method, $url, $version) = m|^(\w+)\s+(.*?)\s*((?:\bHTTP/\d+\.\d+)?)$|) {
	    if ($version ne 'HTTP/1.1') {
		$self->send_http_error(HTTP_VERSION_NOT_SUPPORTED);
		return;
	    }
	    my @headers;
	    while(<>) {
		s/\r?\n$//; # HTTP chomp
		if (my ($name, $value) = /^($token_re)\s*:\s*(.*?)\s*$/o) {
		    # new header
		    push @headers, "${name}:${value}";
		}
		elsif (/^\s+(.*?)\s+$/) {
		    # header continuation
		    unless (@headers) {
			$self->send_http_error(HTTP_BAD_REQUEST);
			return;
		    }
		    $headers[-1] .= " " . $1;
		}
		elsif (/^$/) {
		    # end of headers
		    $self->process_http_request($method, $url, \@headers);
		    last;
		}
		else {
		    $self->send_http_error(HTTP_BAD_REQUEST);
		    return;
		}
	    }
	}
	else {
	    $self->send_http_error(HTTP_BAD_REQUEST);
	    return;
	}
    }
    print STDERR "connection closed\n";
}

sub set_http_request_processor {
    my ($self, $callback, $method, $url) = @_;
    my $children_also = $url =~ s|/\*$||;
    my $matcher = quotemeta("$method $url");
    $matcher .= "(?:/.*)?" if $children_also;
    $matcher = qr/^$matcher$/;
    my $p = $self->{_http_request_processor} ||= [];
    @$p = sort { length $_->[1] } @$p, [$callback, $url, $matcher];
    my $c = $self->{_http_request_processor_cache} ||= {};
    delete $$c{$_} for (grep /$matcher/, keys %$c);
    1
}

sub get_http_request_processor {
    my ($self, $method, $url) = @_;
    my $c = $self->{_http_request_processor_cache} ||= {};
    my $pair = "$method $url";
    $c->{$pair} ||= do {
	my $p = $self->{_http_request_processor} ||= [];
	my $h = (grep $pair =~ $_->[2], @$p)[0]
	    or return undef;
	$h->[0];
    }
}

sub process_http_request {
    my $self = shift;
    my ($method, $url, $headers) = @_;
    my $path = (uri_split $url)[2];
    my $processor = $self->get_http_request_processor($method, $path);
    if ($processor) {
	$processor->($self, $method, $url, $headers);
    }
    else {
	$self->send_http_error(HTTP_NOT_FOUND);
    }
}

sub send_http_response {
    my $self = shift;
    my $code = int shift;
    print join("\r\n",
	       "HTTP/1.1 $code ". http_status_message($code),
	       @_, '', '');
}

sub send_http_response_with_body {
    my $self = shift;
    my $code = shift;
    my $content_type = shift;
    my @headers = (ref $_[0] ? @{shift()} : ());
    my $content = join('', @_);
    $self->send_http_response($code,
			      @headers,
			      "Content-Type: $content_type",
			      "Content-Length: " . length($content));
    print $content;
}

sub send_http_error {
    my ($self, $code) = @_;
    $code ||= HTTP_INTERNAL_SERVER_ERROR;
    my $text = http_status_description($code);
    $self->send_http_response_with_body($code, 'text/plain', $text);
}

sub json {
    my $self = shift;
    $self->{_json} ||= do {
	require JSON;
	JSON->new->ascii->pretty->allow_nonref;
    }
}

sub send_http_response_json {
    my $self = shift;
    my @headers =  (@_ > 1 ? @{shift()} : ());
    my $data = shift;
    $self->send_http_response_with_body(HTTP_OK,
					'application/json',
					\@headers,
					$self->json->encode($data));
}

1;

__END__

=head1 NAME

QVD::HTTPD - The great new QVD::HTTPD!


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use QVD::HTTPD;

    my $foo = QVD::HTTPD->new();
    ...

=head1 FUNCTIONS


=head1 BUGS

Please report any bugs or feature requests to C<bug-qvd-httpd at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=QVD-HTTPD>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=back

=head1 AUTHORS

Salvador FandiE<ntilde>o (sfandino@yahoo.com)

=head1 COPYRIGHT & LICENSE

Copyright 2009 Qindel Consulting S.L., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut


