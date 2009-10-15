package QVD::HKD;

use warnings;
use strict;

use Log::Log4perl qw/:easy/;
use QVD::VMAS;
use QVD::DB;

our $VERSION = '0.01';

sub new {
    my ($class, %opts) = @_;
    my $loop_wait_time = delete $opts{loop_wait_time};
    my $host_id = delete $opts{host_id};
    my $db = QVD::DB->new();
    my $vmas = QVD::VMAS->new($db);
    my $state_map = {
    	stopped => {
	    start 	=> {action => 'start_vm'},
	    _enter	=> {action => 'enter_stopped'},
	},
	starting => {
	    _fail 	=> {action => 'state_failed'},
	    _timeout 	=> {action => 'state_zombie'},
	    _vma_start 	=> {action => 'vm_running'},
	},
	running => {
	    _fail 	=> {state => 'state_failed'},
	    _timeout 	=> {state => 'state_zombie'},
	    _do 	=> {action => 'update_ok_ts'},
	    stop 	=> {action => 'stop_vm'},
	},
	stopping => {
	    _enter 	=> {action => 'enter_stopping'},
	    _fail 	=> {action => 'vm_stopped'},
	    _timeout 	=> {action => 'state_zombie'},
	},
	zombie => {
	    _fail 	=> {action => 'state_failed'},
	    _do 	=> {action => 'signal_zombie_vm'},
	    _timeout 	=> {action => 'kill_vm'},
	    _enter 	=> {action => 'enter_zombie'},
	},
	failed => {
	    _enter 	=> {action => 'enter_failed'},
	},
    };
    my $self = { 
	loop_wait_time => $loop_wait_time,
	host_id => $host_id,
	vmas => $vmas,
	db => $db,
	state_map => $state_map,
    };
    bless $self, $class;
}

sub _handle_signal {
    my $signame = shift;
    INFO "Received $signame";
}

sub _install_signals {
    my $self = shift;
    $SIG{USR1} = \&_handle_signal;
}

sub _next_event {
    my ($self, $vm) = @_;
    my @events = ();
# Push monitoring events
    my $vm_state = $self->{vmas}->get_vm_status(id => $vm->vm_id);
    if ($vm->vm_state ne 'stopped' 
		&& $vm_state->{vm_status} eq 'stopped') {
        push @events, '_fail';
    }
    if (! defined $vm->vma_ok_ts 
		&& exists $vm_state->{vma_status} 
		&& $vm_state->{vma_status} eq 'ok') {
	push @events, '_vma_start';
    }
# Push timeout event

# Push command event
    my $event = $vm->vm_cmd;
    push @events, $event if defined $event;

# Push default "_do" event
    push @events, '_do';

    @events
}

sub _do_actions {
    my $self = shift;
    my $vmas = $self->{vmas};

    my @vms = $vmas->get_vms_for_host($self->{host_id});
# Could we process the VMs in parallel?
    foreach my $vm (@vms) {
	my $vm_id = $vm->vm_id;
	my $vm_state = $vm->vm_state;
	my @events = $self->_next_event($vm);
	while (my $event = shift @events) {
	    my $event_map = $self->{state_map}{$vm_state};
	    unless (exists $event_map->{$event}) {
		DEBUG "VM($vm_id,$vm_state,$event) - event ignored";
		next;
	    }
	    my $action = $event_map->{$event}{action};
	    DEBUG "_do_actions: Handling VM($vm_id,$vm_state,$event) with $action";
	    my $method = $self->can('hkd_action_'.$action);
	    my $new_state;
	    if (defined $method) {
		$new_state = $self->$method($vm, $vm_state, $event);
	    } else {
		ERROR "_do_actions: not implemented: $action";
	    }
# Change state and handle the _enter event.
# Following events are handled in the new state.
	    if (defined $new_state && $new_state ne $vm_state) {
		DEBUG "_do_actions: VM $vm_id: new state $new_state";
		$vmas->push_vm_state($vm, $new_state);
		$vm_state = $new_state;
		unshift @events, '_enter';
	    }
	}
    }
    $self->{db}->txn_commit;
}

sub run {
    my $self = shift;
    $self->_install_signals;
    for (;;) {
	$self->_do_actions();
	sleep $self->{loop_wait_time};
    }
}

sub consume_cmd {
    my ($self, $vm) = @_;
    $self->{vmas}->clear_vm_cmd($vm);
}

sub hkd_action_start_vm {
    my ($self, $vm, $state, $event) = @_;
    INFO "Starting VM ".$vm->vm_id;
    $self->consume_cmd($vm);
    my $r = $self->{vmas}->start_vm(id => $vm->vm_id);
    if (! exists $r->{error} && $r->{vm_status} eq 'starting') {
	return 'starting';
    } else {
	return 'failed';
    }
}

sub hkd_action_vm_stopped {
    my ($self, $vm, $state, $event) = @_;
    $self->{vmas}->clear_vma_ok_ts($vm);
    'stopped'
}

sub hkd_action_state_failed {
    'failed'
}

sub hkd_action_state_zombie {
    'zombie'
}

sub hkd_action_vm_running {
    my ($self, $vm, $state, $event) = @_;
    $self->{vmas}->update_vma_ok_ts($vm);
    'running'
}

sub hkd_action_update_ok_ts {
    my ($self, $vm, $state, $event) = @_;
    $self->{vmas}->update_vma_ok_ts($vm);
    undef
}

sub hkd_action_stop_vm {
    my ($self, $vm, $state, $event) = @_;
    INFO "Stopping VM ".$vm->vm_id;
    my $r = $self->{vmas}->stop_vm(id => $vm->vm_id);
    $self->consume_cmd($vm);
    if ($r->{vm_status} eq 'stopping') {
	return 'stopping';
    } else {
	return 'zombie';
    }
}

sub hkd_action_enter_stopped {
    my ($self, $vm, $state, $event) = @_;
    $self->{vmas}->clear_vm_host($vm);
    undef
}

sub hkd_action_signal_zombie_vm {
    undef
}

sub hkd_action_kill_vm {
    undef
}

sub hkd_action_enter_stopping {
    undef
}

sub hkd_action_enter_failed {
    undef
}

1;

__END__

=head1 NAME

QVD::HKD - The QVD house-keeping daemon

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    use QVD::HKD;
    my $hkd = QVD::HKD->new;
    $hkd->run;

=head2 API

=over

=item new(loop_wait_time => time)

Construct a new HKD. 

=item run

Run the HKD processing loop.

=back

=head1 AUTHOR

Joni Salonen, C<< <jsalonen at qindel.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Qindel Group, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
