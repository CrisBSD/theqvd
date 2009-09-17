package QVD::VMA;

our $VERSION = '0.01';

use warnings;
use strict;

use Proc::ProcessTable;

use parent 'QVD::HTTPD';

sub post_configure_hook {
    my $self = shift;
    my $impl = QVD::VMA::Impl->new();
    $impl->set_http_request_processors($self, '/vma/*');
}

package QVD::VMA::Impl;

use parent 'QVD::SimpleRPC::Server';

sub _get_nxagent_pid {
    return `cat /var/run/qvd/nxagent-pid`;
}

sub _is_nxagent_running {
    my $pid = _get_nxagent_pid;
    if ($pid) {
	return kill 0, $pid;
    } else {
	return 0;
    }
}

sub _is_nxagent_suspended {
    my $status = `cat /var/run/qvd/state`;
    chomp($status);
    return $status eq 'suspended';
}

sub _start_or_resume_session {
    my $pid = _get_nxagent_pid;
    if (_is_nxagent_running) {
	if (_is_nxagent_suspended) {
	    warn "Waking up suspended nxagent..";
	    kill('HUP', $pid);
	} else {
	    warn "Suspending active nxagent to steal session..";
	    kill('HUP', $pid);
	    while (! _is_nxagent_suspended) {
		# FIXME: timeout
		sleep 1;
	    }
	    warn "Waking up suspended nxagent to steal session..";
	    kill('HUP', $pid);
	}
    } else {
	my $pid = fork;
	if (!$pid) {
	    defined $pid or die "fork failed";
	    { exec "xinit gnome-session -- /home/qvd/QVD/ext/QVD-VMA/bin/nxagent-monitor.pl :1000 -display nx/nx,link=lan:1000 -ac" };
	    { exec "/bin/false" };
	    require POSIX;
	    POSIX::_exit(-1);
	}
    }
}

sub SimpleRPC_start_vm_listener {
    my $self = shift;

    _start_or_resume_session;

    # sleep 3;
    {host => 'localhost', port => 5000};
}

1;

__END__

=head1 NAME

QVD::VMA - The great new QVD::VMA!


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use QVD::VMA;

    my $foo = QVD::VMA->new();
    ...

=head1 DESCRIPTION

=head2 FUNCTIONS

=over

=item function1

=item function2

=back

=head1 AUTHOR

Salvador FandiE<ntilde>o (sfandino@yahoo.com)

=head1 BUGS


=head1 COPYRIGHT & LICENSE

Copyright E<copy> 2009 Qindel Formacion y Servicios S.L., all rights
reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

