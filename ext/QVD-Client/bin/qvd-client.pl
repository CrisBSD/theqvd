#!/usr/bin/perl

use strict;
use warnings;

use QVD::HTTPC;
use QVD::HTTP::StatusCodes qw(:status_codes);
use IO::Socket::Forwarder qw(forward_sockets);
use MIME::Base64 qw(encode_base64);

# Forces a flush
$| = 1;

my $username = shift @ARGV;
my $password = shift @ARGV;
my $host = shift @ARGV;
my $port = shift @ARGV // "8443";

my $authorization = 'Basic '.encode_base64("$username:$password", '');

# FIXME: do not use a heuristic but some command line flag for that
my $ssl = ($port =~ /43$/ ? 1 : undef);

my $httpc = QVD::HTTPC->new($host.":".$port, SSL => $ssl);

$httpc->send_http_request(GET => '/qvd/connect_to_vm',
			  headers => [ 'Connection: Upgrade',
			  	       'Authorization: '.$authorization,
				       'Upgrade: QVD/1.0' ]);
while (1) {
    my ($code, $msg, $headers, $body) = $httpc->read_http_response;
    use Data::Dumper;
    print Dumper [http_response => $code, $msg, $headers, $body];
    if ($code == HTTP_SWITCHING_PROTOCOLS) {
	my $ll = IO::Socket::INET->new(LocalPort => 4040,
				       ReuseAddr => 1,
				       Listen => 1);

	# XXX: make media port configurable (4713 for pulseaudio)
	system "nxproxy -S localhost:40 media=4713 &";
	my $s1 = $ll->accept()
	    or die "connection from nxproxy failed";
	undef $ll; # close the listening socket
	my $s2 = $httpc->get_socket;
	forward_sockets($s1, $s2); # , debug => 1);
	last;
    }
    elsif ($code >= 100 and $code < 200) {
	print "$code\ncontinuing...\n"
    }
    else {
	die "unable to connect to remote vm: $code";
    }
}

__END__

=head1 NAME

qvd-client.pl

=head1 DESCRIPTION

probe of concept client for the new QVD

=cut
