package QVD::HKD::VMHandler::KVM;

BEGIN { *debug = \$QVD::HKD::VMHandler::debug }
our $debug;

use strict;
use warnings;

use POSIX;
use AnyEvent;
use AnyEvent::Util;
use QVD::Log;

use parent qw(QVD::HKD::VMHandler);

use QVD::StateMachine::Declarative
    'new'                             => { transitions => { _on_cmd_start                => 'starting',
                                                            _on_cmd_catch_zombie         => 'zombie/beating_to_death'       } },

    'starting'                        => { jump        => 'starting/saving_state' },

    'starting/saving_state'           => { enter       => '_save_state',
                                           transitions => { _on_save_state_done          => 'starting/loading_row'          } },

    'starting/loading_row'            => { enter       => '_load_row',
                                           transitions => { _on_load_row_done            => 'starting/updating_stats',
                                                            _on_load_row_error           => 'stopping/clearing_runtime_row' } },

    'starting/updating_stats'         => { enter       => '_incr_run_attempts',
                                           transitions =>  { _on_incr_run_attempts_done  => 'starting/searching_di',
                                                             _on_incr_run_attempts_bad_result => 'stopping/clearing_runtime_row' } },

    'starting/searching_di'           => { enter       => '_search_di',
                                           transitions => { _on_search_di_done           => 'starting/saving_runtime_row',
                                                            _on_search_di_error          => 'stopping/clearing_runtime_row' } },

    'starting/saving_runtime_row'     => { enter       => '_save_runtime_row',
                                           transitions => { _on_save_runtime_row_done    => 'starting/deleting_cmd',
                                                            _on_save_runtime_row_error   => 'stopping/clearing_runtime_row' },
                                           ignore      => ['_on_save_runtime_row_result'] },

    'starting/deleting_cmd'           => { enter       => '_delete_cmd',
                                           transitions => { _on_delete_cmd_done          => 'starting/calculating_attrs',
                                                            _on_delete_cmd_error         => 'starting/calculating_attrs'        } },

    'starting/calculating_attrs'      => { enter       => '_calculate_attrs',
                                           transitions => { _on_calculate_attrs_done     => 'starting/setting_heavy_mark'       } },

    'starting/setting_heavy_mark'     => { enter       => '_set_heavy_mark',
                                           transitions => { _on_set_heavy_mark_done      => 'starting/allocating_os_disk',
                                                            _on_set_heavy_mark_error     => 'starting/delaying'                 } },

    'starting/delaying'               => { transitions => { _on_cmd_go_heavy             => 'starting/setting_heavy_mark'       } },

    'starting/allocating_os_disk'     => { enter       => '_allocate_os_disk',
                                           transitions => { _on_allocate_os_disk_done    => 'starting/allocating_user_disk',
                                                            _on_allocate_os_disk_error   => 'stopping/clearing_runtime_row' } },

    'starting/allocating_user_disk'   => { enter       => '_allocate_user_disk',
                                           transitions => { _on_allocate_user_disk_done  => 'starting/removing_old_fw_rules',
                                                            _on_allocate_user_disk_error => 'stopping/clearing_runtime_row' } },

    'starting/removing_old_fw_rules'  => { enter       => '_remove_fw_rules',
                                           transitions => { _on_remove_fw_rules_done     => 'starting/allocating_tap',
                                                            _on_remove_fw_rules_error    => 'stopping/clearing_runtime_row',} },

    'starting/allocating_tap'         => { enter       => '_allocate_tap',
                                           transitions => { _on_allocate_tap_done        => 'starting/running_prestart_hook',
                                                            _on_allocate_tap_error       => 'stopping/clearing_runtime_row' } },

    'starting/running_prestart_hook'  => { enter    => '_run_prestart_hook',
                                           transitions => { _on_run_hook_done            => 'starting/setting_fw_rules',
                                                            _on_run_hook_error           => 'stopping/saving_state_2'  } },

    'starting/setting_fw_rules'       => { enter       => '_set_fw_rules',
                                           transitions => { _on_set_fw_rules_done        => 'starting/enabling_iface',
                                                            _on_set_fw_rules_error       => 'stopping/saving_state_2' } },

    'starting/enabling_iface'         => { enter       => '_enable_iface',
                                           transitions => { _on_enable_iface_done        => 'starting/launching',
                                                            _on_enable_iface_error       => 'stopping/saving_state_2' } },

    'starting/launching'              => { enter       => '_launch_process',
                                           transitions => { _on_launch_process_done      => 'starting/waiting_for_vma',
                                                            _on_launch_process_error     => 'stopping/saving_state_2' } },

    'starting/waiting_for_vma'        => { enter       => '_start_vma_monitor',
                                           leave       => '_stop_vma_monitor',
                                           # leave defined as a sub below
                                           transitions => { _on_alive                    => 'running/saving_state',
                                                            _on_dead                     => 'stopping/killing_vm',
                                                            _on_goto_debug               => 'debugging/saving_state',
                                                            on_hkd_stop                  => 'stopping/saving_state',
                                                            _on_vm_process_done          => 'stopping/saving_state_2' } },

    'running/saving_state'            => { enter       => '_save_state',
                                           transitions => { _on_save_state_done          => 'running/updating_stats',
                                                            _on_save_state_error         => 'stopping/saving_state' } },

    'running/updating_stats'          => { enter       => '_incr_run_ok',
                                           transitions =>  { _on_incr_run_ok_done        => 'running/running_poststart_hook',
                                                             _on_incr_run_ok_error       => 'running/running_poststart_hook' },
                                           ignore      => [qw(_on_incr_run_ok_result)]                                          },

    'running/running_poststart_hook'  => {  enter       => '_run_poststart_hook',
                                            transitions => { _on_run_hook_done            => 'running/unsetting_heavy_mark',
                                                             _on_run_hook_error           => 'stopping/saving_state'          } },

    'running/unsetting_heavy_mark'    => { enter       => '_unset_heavy_mark',
                                           transitions => { _on_unset_heavy_mark_done    => 'running/monitoring'              } },

    'running/monitoring'              => { enter       => '_start_vma_monitor',
                                           leave       => '_stop_vma_monitor',
                                           # TODO: check these transitions:
                                           transitions => { _on_cmd_stop                 => 'stopping/deleting_cmd',
                                                            on_hkd_stop                  => 'stopping/saving_state',
                                                            _on_dead                     => 'stopping/saving_state',
                                                            _on_goto_debug               => 'debugging/saving_state',
                                                            _on_vm_process_done          => 'stopping/saving_state_2' } },

    'debugging/saving_state'          => { enter       => '_save_state',
                                           transitions => { _on_save_state_done          => 'debugging/unsetting_heavy_mark',
                                                            _on_save_state_error         => 'stopping/saving_state'           },
                                           delay       => [qw(_on_vm_process_done)]                                            },

    'debugging/unsetting_heavy_mark'  => { enter       =>  '_unset_heavy_mark',
                                           transitions => { _on_unset_heavy_mark_done    => 'debugging/waiting_for_vma'      } },

    'debugging/waiting_for_vma'       => { enter       => '_start_vma_monitor',
                                           leave       => '_stop_vma_monitor',
                                           transitions => { _on_alive                    => 'running/saving_state',
                                                            _on_cmd_stop                 => 'stopping/deleting_cmd',
                                                            on_hkd_stop                  => 'stopping/saving_state',
                                                            _on_vm_process_done          => 'stopping/saving_state_2' },
                                           ignore      => [qw(_on_dead
                                                              _on_goto_debug)] },

    'stopping/deleting_cmd'           => { enter       => '_delete_cmd',
                                           transitions => { _on_delete_cmd_done          => 'stopping/saving_state'           } },

    'stopping/saving_state'           => { enter       => '_save_state',
                                           transitions => { _on_save_state_done          => 'stopping/setting_heavy_mark',
                                                            _on_save_state_error         => 'stopping/setting_heavy_mark'     } },

    'stopping/setting_heavy_mark'     => { enter       => '_set_heavy_mark',
                                           transitions => { _on_set_heavy_mark_done      => 'stopping/powering_off',
                                                            _on_set_heavy_mark_error     => 'stopping/delaying'               } },

    'stopping/delaying'               => { transitions => { _on_cmd_go_heavy             => 'stopping/setting_heavy_mark'     } },

    'stopping/powering_off'           => { enter       => '_poweroff',
                                           leave       => '_abort_all',
                                           transitions => { _on_rpc_poweroff_error       => 'stopping/killing_vm',
                                                            _on_vm_process_done          => 'stopping/removing_fw_rules',
                                                            _on_rpc_poweroff_result      => 'stopping/waiting_for_vm_to_exit' } },

    'stopping/waiting_for_vm_to_exit' => { enter       => '_set_state_timer',
                                           leave       => '_abort_all',
                                           transitions => { _on_vm_process_done          => 'stopping/removing_fw_rules',
                                                            _on_state_timeout            => 'stopping/killing_vm' } },

    'stopping/killing_vm'             => { enter       => '_kill_vm',
                                           leave       => '_abort_all',
                                           transitions => { _on_vm_process_done          => 'stopping/removing_fw_rules' } },

    'stopping/saving_state_2'         => { enter       => '_save_state',
                                           transitions => { _on_save_state_done          => 'stopping/removing_fw_rules',
                                                            _on_save_state_error         => 'stopping/removing_fw_rules'     } },

    'stopping/removing_fw_rules'      => { enter       => '_remove_fw_rules',
                                           transitions => { _on_remove_fw_rules_done     => 'stopping/running_poststop_hook',
                                                            _on_remove_fw_rules_error    => 'stopping/running_poststop_hook' } },

    'stopping/running_poststop_hook'  => { enter    => '_run_prestart_hook',
                                           transitions => { _on_run_hook_done            => 'stopping/clearing_runtime_row',
                                                            _on_run_hook_error           => 'stopping/clearing_runtime_row'  } },

    'stopping/clearing_runtime_row'   => { enter       => '_clear_runtime_row',
                                           transitions => { _on_clear_runtime_row_done   => 'stopped' },
                                           ignore      => ['_on_clear_runtime_row_result',
                                                           '_on_clear_runtime_row_bad_result'] },

    'stopped'                         => { enter       => '_call_on_stopped' },

    'zombie/beating_to_death'         => { jump        => 'zombie/saving_state' },

    'zombie/saving_state'             => { enter       => '_save_state',
                                           transitions => { _on_save_state_done          => 'zombie/calculating_attrs',
                                                            _on_save_state_error         => 'zombie/calculating_attrs',       } },

    'zombie/calculating_attrs'        => { enter       => '_calculate_attrs',
                                           transitions => { _on_calculate_attrs_done     => 'zombie/removing_fw_rules'            } },

    'zombie/removing_fw_rules'        => { enter       => '_remove_fw_rules',
                                           transitions => { _on_remove_fw_rules_done     => 'zombie/clearing_runtime_row',
                                                            _on_remove_fw_rules_error    => 'zombie/unsetting_heavy_mark'    } },

    'zombie/clearing_runtime_row'     => { enter       => '_clear_runtime_row',
                                           transitions => { _on_clear_runtime_row_done   => 'stopped',
                                                            _on_clear_runtime_row_error  => 'zombie/unsetting_heavy_mark'    } },

    'zombie/unsetting_heavy_mark'     => { enter       => '_unset_heavy_mark',
                                           transitions => { _on_unset_heavy_mark_done    => 'zombie'                         } },

    'zombie'                          => { enter       => '_set_state_timer',
                                           leave       => '_abort_all',
                                           transitions => { _on_state_timeout => 'zombie/beating_to_death',
                                                            on_hkd_stop => 'stopped'                                         } },

    __any__                           => { delay       => ['_on_cmd_stop',
                                                           '_on_vm_process_done',
                                                           'on_hkd_stop']                                                      };

sub _on_cmd_start :OnState('__any__') { shift->_maybe_callback('on_delete_cmd') }


# FIXME: move this out of here, maybe into a module:
use constant TUNNEL_DEV => '/dev/net/tun';
use constant STRUCT_IFREQ => "Z16 s";
use constant IFF_NO_PI => 0x1000;
use constant IFF_TAP => 2;
use constant TUNSETIFF => 0x400454ca;

sub _allocate_tap {
    my $self = shift;
    eval {
        open my $tap_fh, '+<', TUNNEL_DEV() or LOGDIE "Can't open ".TUNNEL_DEV().": $!";
        $self->{tap_fh} = $tap_fh;
        my $ifreq = pack(STRUCT_IFREQ(), 'qvdtap%d', IFF_TAP()|IFF_NO_PI());
        ioctl $tap_fh, TUNSETIFF(), $ifreq or LOGDIE "Can't create tap interface: $!";
        $self->{iface} = unpack STRUCT_IFREQ(), $ifreq;
    };
    if ($@) {
        ERROR "Allocating TAP device: $@";
        return $self->_on_allocate_tap_error
    }

    # FIXME: add the ebtables thing back again
    # $noded->_make_ebtables_tap_chain($tap_if);

    $self->_run_cmd([$self->_cfg('command.brctl'),
                     addif => $self->_cfg('vm.network.bridge'),
                     $self->{iface}]);
}

sub _enable_iface {
    my $self = shift;
    $self->_run_cmd([$self->_cfg('command.ifconfig'), $self->{iface}, 'up']);
}

sub _calculate_attrs {
    # TODO: move attribute calculation here!
    shift->_on_calculate_attrs_done

}

sub _allocate_os_disk {
    my $self = shift;
    my $image_path = $self->_cfg('path.storage.images') . '/' . $self->{di_path};
    unless (-f $image_path) {
        ERROR "Image '$image_path' attached to VM '$self->{vm_id}' does not exist on disk";
        return $self->_on_allocate_os_disk_error;
    }
    unless ($self->{use_overlay}) {
        $self->{os_image_path} = $image_path;
        return $self->_on_allocate_os_disk_done;
    }

    # FIXME: use a better policy for overlay allocation
    my $overlays_dir = $self->_cfg('path.storage.overlays');
    $overlays_dir =~ s|/*$|/|;
    my $overlay_path = $self->{os_image_path} = $overlays_dir . join('-', $self->{di_id}, $self->{vm_id}, 'overlay.qcow2');
    if (-f $overlay_path) {
        if ($self->_cfg('vm.overlay.persistent')) {
            DEBUG "Reusing persistent overlay '$overlay_path'";
            return $self->_on_allocate_os_disk_done;
        }
        DEBUG "Discarding overlay '$overlay_path'";
        unlink $overlay_path;
    }
    mkdir $overlays_dir, 0755 or WARN "mkdir: 'overlays_dir': $!";
    unless (-d $overlays_dir) {
        ERROR "Overlays directory '$overlays_dir' does not exist";
        return $self->_on_allocate_os_disk_error
    }

    # FIXME: use a relative path to the base image?
    #my $image_relative = File::Spec->abs2rel($image, $overlays_path);
    $self->_run_cmd([ $self->_cfg('command.kvm-img'),
                      'create',
                      -f => 'qcow2',
                      -b => $image_path,
                      $overlay_path ]);
}

sub _allocate_user_disk {
    my $self = shift;
    my $size = $self->{user_storage_size};
    unless (defined $size) {
        DEBUG 'Not allocating user storage';
        return $self->_on_allocate_user_disk_done;
    }

    my $homes_dir = $self->_cfg('path.storage.homes');
    $homes_dir =~ s|/*$|/|;
    my $image_path = $self->{user_image_path} = "$homes_dir$self->{vm_id}-data.qcow2";
    if (-f $image_path) {
        DEBUG "Reusing user storage at '$image_path'";
        return $self->_on_allocate_user_disk_done;
    }
    mkdir $homes_dir, 0755 or WARN "mkdir: '$homes_dir': $!";
    unless (-d $homes_dir) {
        ERROR "Homes directory '$homes_dir' does not exist";
        return $self->_on_allocate_user_disk_error;
    }

    $self->_run_cmd([ $self->_cfg('command.kvm-img'),
                      'create',
                      -f => 'qcow2',
                      $image_path ]);
}

sub _launch_process {
    my $self = shift;
    my @cmd = ( $self->_cfg('command.kvm'),
                -m => $self->{memory},
                -name => "qvd/$self->{vm_id}/$self->{name}");

    my $use_virtio = $self->_cfg('vm.kvm.virtio');
    my $nic = "nic,macaddr=$self->{mac},vlan=0";
    $nic .= ',model=virtio' if $use_virtio;
    push @cmd, (-net => $nic, -net => 'tap,vlan=0,fd=3');

    my $redirect_io = $self->_cfg('vm.serial.capture');
    if (defined $self->{serial_port}) {
        DEBUG "Using serial port '$self->{serial_port}'";
        push @cmd, -serial => "telnet::$self->{serial_port},server,nowait,nodelay";
        undef $redirect_io;
    } else {
        DEBUG 'No serial port';
    }

    if ($redirect_io) {
        my $captures_dir = $self->_cfg('path.serial.captures');
        mkdir $captures_dir, 0700 or WARN "mkdir: '$captures_dir': $!";
        if (-d $captures_dir) {
            my @t = gmtime; $t[5] += 1900; $t[4] += 1;
            my $ts = sprintf("%04d-%02d-%02d-%02d:%02d:%2d-GMT0", @t[5,4,3,2,1,0]);
            DEBUG "Redirecting I/O to '$captures_dir/capture-$self->{name}-$ts.txt'";
            push @cmd, -serial => "file:$captures_dir/capture-$self->{name}-$ts.txt";
        }
        else {
            ERROR "Captures directory '$captures_dir' does not exist";
        }
    }

    if ($self->{vnc_port}) {
        my $vnc_display = $self->{vnc_port} - 5900;
        my $vnc_opts = $self->_cfg('vm.vnc.opts');
        $vnc_display .= ",$vnc_opts" if $vnc_opts =~ /\S/;
        DEBUG "VNC is at display ':$vnc_display'";
        push @cmd, -vnc => ":$vnc_display";
    }
    else {
        DEBUG 'No VNC';
        push @cmd, '-nographic';
    }

    if ($self->{mon_port}) {
        push @cmd, -monitor, "telnet::$self->{mon_port},server,nowait,nodelay";
        DEBUG "Using monitor port '$self->{mon_port}'";
    } else {
        DEBUG 'No monitor port';
    }

    my $hda = "file=$self->{os_image_path},index=0,media=disk";
    $hda .= ',if=virtio,boot=on' if $use_virtio;
    push @cmd, -drive => $hda;

    if (defined $self->{user_image_path}) {
        my $hdb_index = $self->_cfg('vm.kvm.home.drive.index');
        my $hdb = "file=$self->{user_image_path},index=$hdb_index,media=disk";
        $hdb .= ',if=virtio' if $use_virtio;
        DEBUG "Using user storage '$self->{user_image_path}' ($hdb) for VM '$self->{vm_id}'";
        push @cmd, -drive => $hdb;
    }

    my $pid = fork;
    unless ($pid) {
        unless (defined $pid) {
            ERROR "Unable to fork virtual machine process: $!";
            return $self->_on_launch_process_error;
        }
        eval {
            DEBUG "exec cmd: '" . join(" ", @cmd) . "'\n";
            #setpgrp;   # do not kill kvm when HKD runs on terminal and user CTRL-C's it
	    open STDIN, '<', '/dev/null' or LOGDIE "can't open /dev/null\n";
	    open STDOUT, '>', '/dev/null' or LOGDIE "can't redirect STDOUT to /dev/null\n";

            setpriority(1, 0, 10); # run VMs with low priority so in
                                   # case the machine gets overloaded,
                                   # the noded and hkd daemons do not
                                   # become unresponsive.
                                   # (PRIO_PGRP => 1, current PGRP => 0)
            $^F = 3;
            if (fileno $self->{tap_fh} == 3) {
                POSIX::fcntl($self->{tap_fh}, F_SETFD, fcntl($self->{tap_fh}, F_GETFD, 0) & ~FD_CLOEXEC)
                        or LOGDIE "fcntl failed: $!";
            }
            else {
                POSIX::dup2(fileno $self->{tap_fh}, 3) or LOGDIE "dup2 failed: $!";
            }

            # system "cat /proc/$$/fdinfo/3 >>/tmp/hkd-fdinfo";

	    POSIX::dup2(1, 2) or LOGDIE "dup2 failed (2): $!";
            # DEBUG "cmd: >" . join("< >", @cmd) . "<\n";

	    exec @cmd or LOGDIE "exec failed\n";
	};
 	ERROR "Unable to start VM: $@";
 	POSIX::_exit(1);
    }
    DEBUG "kvm pid: $pid\n";
    $self->{pid} = $pid;
    $self->{vm_watcher} = AnyEvent->child(pid => $pid,
                                          cb => sub {
                                              $debug and $self->_debug("kvm process exited with code $?");
                                              $self->_on_vm_process_done($_[1])
                                          });
    $self->{last_seen_alive} = time;
    $self->{failed_vma_count} = 0;

    $self->_on_launch_process_done;
}

sub _kill_vm {
    my $self = shift;
    DEBUG "Sending SIGINT to PID '$self->{pid}'";
    kill INT => $self->{pid};
    $self->_call_after($self->_cfg("internal.hkd.vmhandler.killer.delay"), '_kill_vm');
}

sub _run_hook {
    my ($self, $name) = @_;
    DEBUG "TODO: where are hooks stored when using images?";
    $self->_on_run_hook_done;
}

1;
