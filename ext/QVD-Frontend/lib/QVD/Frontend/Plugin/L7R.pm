package QVD::Frontend::Plugin::L7R;

use strict;
use warnings;

use IO::Socket::INET;
use URI::Split qw(uri_split);

use IO::Socket::Forwarder qw(forward_sockets);
use QVD::VMAS;
use QVD::HTTP::StatusCodes qw(:status_codes);
use QVD::HTTP::Headers qw(header_eq_check);
use QVD::URI qw(uri_query_split);

sub set_http_request_processors {
    my ($class, $server, $url_base) = @_;
    $server->set_http_request_processor( \&_connect_to_vm_processor,
					 GET => $url_base . "connect_to_vm");
}

sub _connect_to_vm_processor {
    my ($server, $method, $url, $headers) = @_;
    # FIXME Move this to a configuration file
    my $vm_start_timeout = 60;

    unless (header_eq_check($headers, Connection => 'Upgrade') and
	    header_eq_check($headers, Upgrade => 'QVD/1.0')) {
	$server->send_http_error(HTTP_UPGRADE_REQUIRED);
	return;
    }

    my ($path, $query) = (uri_split $url)[2, 3];
    my %params = uri_query_split $query;
    my $user_id = $params{user_id};
    unless (defined $user_id) {
	$server->send_http_error(HTTP_UNPROCESSABLE_ENTITY);
	return;
    }

    $server->send_http_response(HTTP_PROCESSING,
				'X-QVD-VM-Status: Checking VM');

    my $vmas = QVD::VMAS->new();
    my @vms = $vmas->get_vms_for_user($user_id);
    # FIXME limits number of VMs per user to 1
    my $vm = $vms[0];
    unless ($vmas->assign_host_for_vm($vm)) {
	# FIXME VM could not be assigned to a host, send error to client?
	$server->send_http_error(HTTP_BAD_GATEWAY);
	return;
    }
    my $r = $vmas->start_vm($vm);
    # The VM was not already running or there was some error
    unless ($r->{vm_status} eq 'started') {
	# FIXME Pass the error message to the client?
	$server->send_http_error(HTTP_BAD_GATEWAY), return
		if exists $r->{error};

	# Wait for the VMA to come online
	# FIXME use time() for checking timeout
	my $timeout_counter = $vm_start_timeout/5;
	while ($timeout_counter --> 0) {
	    $server->send_http_response(HTTP_PROCESSING,
		'X-QVD-VM-Status: Starting VM');
	    $r = $vmas->get_vm_status($vm);
	    last if $r->{vma_status} eq 'ok';
	    sleep 5;
	}
	# Timed out
	# FIXME Pass the error message to the client?
	do {$server->send_http_error(HTTP_BAD_GATEWAY), return}
		if $timeout_counter < 0;
    }
    $r = $vmas->start_vm_listener($vm)
	or do {
	    $server->send_http_error(HTTP_BAD_GATEWAY);
	    return;
	};

    for (1..4) {
	sleep $_;
	$server->send_http_response(HTTP_PROCESSING,
				    'X-QVD-VM-Status: Connecting to VM',
				    "X-QVD-VM-Info: host=$r->{host}, port=$r->{port}");

	my $socket = IO::Socket::INET->new(PeerAddr => $r->{host},
					   PeerPort => $r->{port},
					   Proto => 'tcp');
	unless ($socket) {
	    $server->send_http_response(HTTP_PROCESSING,
					'X-QVD-VM-Status: Retry connection',
					"X-QVD-VM-Info: Connection to vm failed");

	    next;
	}

	$server->send_http_response(HTTP_SWITCHING_PROTOCOLS,
					'X-QVD-VM-Status: Connected to VM');

	forward_sockets(\*STDIN, $socket);
    }
    $server->send_http_error(HTTP_BAD_GATEWAY);
}

1;

__END__

=head1 NAME

QVD::Frontend::Plugin::L7R - plugin for L7R functionality

=head1 SYNOPSIS

  use QVD::Frontend::Plugin::L7R;
  QVD::Frontend::Plugin::L7R->set_http_request_processors($httpd, $base_url);

=head1 DESCRIPTION

This module wraps the L7R functionality as a plugin for L<QVD::Frontend>.

=head2 API

=over

=item QVD::Frontend::Plugin::L7R->set_http_request_processors($httpd, $base_url)

registers the plugin into the HTTP daemon C<$httpd> at the given
C<$base_url>.

=back

=head1 AUTHOR

Salvador FandiE<ntilde>o, C<< <sfandino at yahoo.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Qindel Formacion y Servicios S.L., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

