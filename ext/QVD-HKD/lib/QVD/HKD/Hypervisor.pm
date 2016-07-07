package QVD::HKD::Hypervisor;

use strict;
use warnings;

use parent qw(QVD::HKD::Agent);

use Class::StateMachine::Declarative
    __any__ => { ignore => [qw(_on_done _on_error)] },
    new     => { transitions => { _on_run => 'running' } },
    running => { transitions => { _on_hkd_done => 'stopped' } },
    stopped => { enter => '_on_stopped' };

sub ok { shift->state eq 'running' }

sub name {
    my $self = shift;
    $self->{name} //= do {
        my $name = $self->ref;
        $name =~ s/.*:://;
        lc $name;
    };
}

1;
