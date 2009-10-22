package QVD::VMAS::VMAClient;

use strict;
use warnings;

use parent 'QVD::SimpleRPC::Client';
use Config::Tiny;

sub new {
    my $config = Config::Tiny->new();
    $config = Config::Tiny->read('config.ini');
    my $vm_state_starting_timeout = $config->{timeouts}->{vma_response_timeout};

    my ($class, $host, $port) = @_;
    $class->SUPER::new("http://$host:$port/vma/", timeout => $vm_state_starting_timeout);
}

1;

__END__

=head1 NAME

QVD::VMAS::VMAClient - RPC client for the Virtual Machine Agent.

=head1 SYNOPSIS

	use QVD::VMAS::VMAClient;
	my $vma_client = QVD::VMAS::VMAClient->new('localhost', 3030);

=head1 DESCRIPTION

This module implements the VMA RPC client. See the documentation of the VMA RPC
server (QVD::VMA) to see what calls are available.

=head2 API

=over

=item new(host, port)

Create a vma client that connects to the VMA running at the given host and port.

=back

=head1 AUTHOR

Joni Salonen, C<< <jsalonen at qindel.es> >>

=head1 COPYRIGHT & LICENSE

Copyright C<copy> 2009 Qindel Formacion y Servicios S.L., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

