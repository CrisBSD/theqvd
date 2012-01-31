package QVD::HKD::VMHandler;

our $debug = 1;

use strict;
use warnings;

use POSIX;
use AnyEvent;
use AnyEvent::Util;
use Linux::Proc::Net::TCP;
use QVD::Log;
use Carp;

use QVD::HKD::VMAMonitor;

use parent qw(QVD::HKD::Agent);

my %hypervisor_class = map { $_ => __PACKAGE__ . '::' . uc $_ } qw(kvm lxc);

my $off = 0;
sub _allocate_tcp_port {
    my $self = shift;
    my $base = shift // 2000;
    my $tcp = Linux::Proc::Net::TCP->read;
    my %used = map { $_ => 1 } $tcp->listener_ports;
    while (1) {
	$off++;
	my $port = $base + $off;
	return $port unless $used{$port};
    }
}

sub _ip_to_mac {
    shift;
    my $ip = shift;
    my (undef, @hex) = map sprintf('%02x', $_), split /\./, $ip;
    join(':', '54:52:00', @hex);
}

sub new {
    my ($class, %opts) = @_;
    my $vm_id = delete $opts{vm_id};
    my $on_stopped = delete $opts{on_stopped};
    my $on_delete_cmd = delete $opts{on_delete_cmd};
    my $dhcpd_handler = delete $opts{dhcpd_handler};
    my $self = $class->SUPER::new(%opts);
    $self->{vm_id} = $vm_id;
    $self->{dhcpd_handler} = $dhcpd_handler;
    $self->{on_stopped} = $on_stopped;
    $self->{on_delete_cmd} = $on_delete_cmd;

    my $hypervisor = $self->_cfg('vm.hypervisor');
    my $hypervisor_class = $hypervisor_class{$hypervisor} // croak "unsupported hypervisor $hypervisor";
    eval "require $hypervisor_class; 1" or croak "unable to load module $hypervisor_class:\n$@";
    $self->bless($hypervisor_class);
    $self->_init_hypervisor;
    $self;
}

sub _init_hypervisor {}

sub on_cmd {
    my ($self, $cmd) = @_;
    my $method = $self->can("_on_cmd_$cmd");
    if ($method) {
        $method->($self);
    }
    else {
        $debug and $self->_debug("unsupported command $cmd received by vm $self->{vm_id}");
    }
}

sub _save_state {
    my $self = shift;
    my $state = $self->_main_state;
    $debug and $self->_debug("changing database state to $state");
    $self->_query('update vm_runtimes set vm_state = $1 where vm_id = $2 and host_id = $3',
                  $state, $self->{vm_id}, $self->{node_id});
}

sub _on_save_state_result {}

sub _load_row {
    my $self = shift;
    $self->_query_1('select name, user_id, osf_id, di_tag, ip, storage from vms where id = $1', $self->{vm_id});
}

sub _on_load_row_result {
    my ($self, $res) = @_;
    @{$self}{qw(name user_id osf_id di_tag ip storage)} = $res->row;
    $self->{mac} = $self->_ip_to_mac($self->{ip});
    $self->{dhcpd_handler}->register_mac_and_ip(@$self{qw(vm_id mac ip)});
}

sub _incr_run_attempts {
    my $self = shift;
    $self->_query('update vm_counters set run_attempts = run_attempts + 1 where vm_id = $1', $self->{vm_id});
}

sub _on_incr_run_attempts_result {}

sub _incr_run_ok {
    my $self = shift;
    $self->_query('update vm_counters set run_ok = run_ok + 1 where vm_id = $1', $self->{vm_id});
}

sub _search_di {
    my $self = shift;
    $self->_query_1(<<'SQL', @$self{qw(osf_id di_tag)});
select dis.id, dis.path, osfs.use_overlay, osfs.user_storage_size, memory
    from di_tags, dis, osfs
    where
        dis.osf_id = osfs.id    and
        di_tags.di_id = dis.id  and
        osfs.id = $1            and
        di_tags.tag = $2
SQL
}

sub _on_search_di_result {
    my ($self, $res) = @_;
    @{$self}{qw(di_id di_path use_overlay user_storage_size memory)} = $res->row;
}

sub _save_runtime_row {
    my $self = shift;

    $self->{vma_port}    = $self->_cfg('internal.vm.port.vma');
    $self->{x_port}      = $self->_cfg('internal.nxagent.display') + 4000;
    $self->{ssh_port}    = $self->_cfg('internal.vm.port.ssh');
    $self->{vnc_port}    = $self->_allocate_tcp_port if $self->_cfg('vm.vnc.redirect');
    $self->{serial_port} = $self->_allocate_tcp_port if $self->_cfg('vm.serial.redirect');
    $self->{mon_port}    = $self->_allocate_tcp_port if $self->_cfg('internal.vm.monitor.redirect');

    $self->_query_1(<<'SQL', @{$self}{qw(ip vma_port x_port ssh_port vnc_port serial_port mon_port vm_id)});
update vm_runtimes
    set
        vm_address     = $1,
        vm_vma_port    = $2,
        vm_x_port      = $3,
        vm_ssh_port    = $4,
        vm_vnc_port    = $5,
        vm_serial_port = $6,
        vm_mon_port    = $7
    where
        vm_id          = $8
SQL
}


# FIXME: move this out of here, maybe into a module:
use constant TUNNEL_DEV => '/dev/net/tun';
use constant STRUCT_IFREQ => "Z16 s";
use constant IFF_NO_PI => 0x1000;
use constant IFF_TAP => 2;
use constant TUNSETIFF => 0x400454ca;

sub _fw_rules {
    my $self = shift;
    my $vm_id = $self->{vm_id};
    my $ip = $self->{ip};
    my $mac = $self->{mac};
    my $iface = $self->{iface};

    # this ebrules rules are just to forbid MAC or IP spoofing
    # everything else is done using global rules.

    my $INPUT   = "QVD_${vm_id}_INPUT";
    my $FORWARD = "QVD_${vm_id}_FORWARD";

    return ( [-N => $INPUT,   -P => 'ACCEPT'],
             [-N => $FORWARD, -P => 'ACCEPT'],

             [-A => $FORWARD => -s => '!', $mac, -j => 'DROP'],
             [-A => $INPUT   => -s => '!', $mac, -j => 'DROP'],
             [-A => $FORWARD => -p => '0x800', '--ip-source' => '!', $ip, -j => 'DROP'],
             [-A => $INPUT   => -p => '0x800', '--ip-protocol' => '17',   # allow DHCP requests to host
                                        '--ip-source' => '0.0.0.0',
                                        '--ip-destination-port' => '67', -j => 'ACCEPT'],
             [-A => $FORWARD => -p => '0x800', '--ip-protocol' => '17',   # do not let DHCP traffic leave the host
                                        '--ip-destination-port' => '67', -j => 'DROP'],
             [-A => $INPUT   => -p => '0x800', '--ip-source' => '!', $ip, -j => 'DROP'],

             [-A => INPUT    => -i => $iface, -j => $INPUT  ],
             [-A => FORWARD  => -i => $iface, -j => $FORWARD] );
}

sub _set_fw_rules {
    my $self = shift;
    if ($self->_cfg('internal.vm.network.firewall.enable')) {
        my $ebtables = $self->_cfg('command.ebtables');
        for my $rule ($self->_fw_rules) {
            $debug and $self->_debug("adding ebtables entry @$rule");
            if (system $ebtables => @$rule) {
                $debug and $self->_debug("unable to add ebtables entry, rc: " . ($? >> 8));
                return $self->_on_set_fw_rules_error;
            }
        }
    }
    else {
        $debug and $self->_debug("setup of VM firewall rules skipped, do you really need to do that?");
    }
    $self->_on_set_fw_rules_done;
}

sub _remove_fw_rules {
    my $self = shift;
    if ($self->_cfg('internal.vm.network.firewall.enable')) {
        my $vm_id = $self->{vm_id};
        my $ebtables = $self->_cfg('command.ebtables');
        for my $chain (qw(INPUT FORWARD)) {
            my $target = "QVD_${vm_id}_${chain}";
            my $j = quotemeta $target;
            $j = qr/\b$j$/;
            $debug and $self->_debug("retrieving list of ebtables entries for $chain");
            for (`$ebtables -L $chain --Ln`) {
                chomp;
                if ($_ =~ $j) {
                    my ($n) = split /\./;
                    $debug and $self->_debug("deleting rule $_");
                    system $ebtables => -D => $chain, $n and
                        $debug and $self->_debug("unable to delete rule, rc: " . ($? << 8));
                }
            }
            system $ebtables => -X => $target and
                $debug and $self->_debug("unable to delete chain $target, rc: " . ($? << 8));

            unless ("$ebtables -L $target >/dev/null 2>&1") {
                $debug and $self->_debug("deletion of chain $target failed");
                $self->_on_remove_fw_rules_error;
            }
        }
    }
    else {
        $debug and $self->_debug("cleanup of VM firewall rules skipped");
    }
    $self->_on_remove_fw_rules_done
}

sub _vma_url {
    my $self = shift;
    sprintf "http://%s:%d/vma", $self->{ip}, $self->{vma_port};
}

sub _start_vma_monitor {
    my $self = shift;
    my $vma_monitor = $self->{vma_monitor} = QVD::HKD::VMAMonitor->new(config => $self->{config},
                                                                       on_failed => sub { $self->_on_failed_vma_monitor },
                                                                       on_alive => sub { $self->_on_alive },
                                                                       rpc_service => $self->_vma_url);
    $self->{last_seen_alive} = time;
    $vma_monitor->run;
}

sub _stop_vma_monitor {
    my $self = shift;
    $debug and $self->_debug('stopping vma monitor');
    my $vma_monitor = delete $self->{vma_monitor};
    $vma_monitor->stop;
}

sub _on_alive {
    my $self = shift;
    $self->{last_seen_alive} = time;
    $self->{failed_vma_count} = 0;
}

sub _on_failed_vma_monitor {
    my $self = shift;
    my $failed_vma_count = ++$self->{failed_vma_count};
    my $state_key = ($self->state =~ /^starting/ ? 'starting' : 'running');
    my $max = $self->_cfg("internal.hkd.vmhandler.vma.failed.max_count.on.$state_key");

    $debug and $self->_debug("failed_vma_monitor, tries: $failed_vma_count/$max");

    if ($failed_vma_count >= $max) {
        my $max_time = $self->_cfg("internal.hkd.vmhandler.vma.failed.max_time.on.$state_key");
        $debug and $self->_debug("failed_vma_monitor, time: " .(time - $self->{last_seen_alive}). "/$max_time");
        if (time - $self->{last_seen_alive} > $max_time) {
            if ($self->_cfg('internal.vm.debug.enable')) {
                $debug and $self->_debug("calling _on_goto_debug");
                $self->_on_goto_debug;

            }
            else {
                $debug and $self->_debug("calling _on_dead");
                $self->_on_dead;
            }
        }
    }
}

sub _poweroff {
    my $self = shift;
    $self->{rpc_service} = $self->_vma_url;
    $self->_rpc('poweroff');
}

sub _set_state_timer {
    my $self = shift;
    my $state = $self->_main_state;
    $self->_call_after($self->_cfg("internal.hkd.vmhandler.timeout.on_state.$state"), '_on_state_timeout');
}

sub _clear_runtime_row {
    my $self = shift;
    my $state = $self->_main_state;
    # FIXME: final state could also be 'failed', currently 'stopped'
    # is hard-coded here.
    $self->_query(<<'SQL', $self->{vm_id}, $self->{node_id});
update vm_runtimes
    set
        vm_state       = 'stopped',
        host_id        = NULL,
        vm_vma_port    = NULL,
        vm_x_port      = NULL,
        vm_ssh_port    = NULL,
        vm_vnc_port    = NULL,
        vm_serial_port = NULL,
        vm_mon_port    = NULL,
        vm_address     = NULL,
        vm_cmd         = NULL
    where
        vm_id   = $1  and
        host_id = $2
SQL
}

sub _on_clear_runtime_row_result {}
sub _on_clear_runtime_row_bad_result {}

sub _call_on_stopped { shift->_maybe_callback('on_stopped') }

1;
