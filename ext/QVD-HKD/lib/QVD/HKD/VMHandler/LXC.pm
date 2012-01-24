package QVD::HKD::VMHandler::LXC;

BEGIN { *debug = \$QVD::HKD::VMHandler::debug }
our $debug;

use strict;
use warnings;
use 5.010;

use POSIX;
use AnyEvent;
use AnyEvent::Util;
use QVD::Log;
use File::Temp qw(tempfile);
use Linux::Proc::Mountinfo;
use File::Spec;

use parent qw(QVD::HKD::VMHandler);

use QVD::StateMachine::Declarative
    'new'                             => { transitions => { _on_cmd_start                => 'starting',
                                                            _on_cmd_catch_zombie         => 'zombie/beating_to_death'          } },

    'starting'                        => { jump        => 'starting/saving_state'                                                },

    'starting/saving_state'           => { enter       => '_save_state',
                                           transitions => { _on_save_state_done          => 'starting/loading_row',
                                                            _on_save_state_error         => 'stopped'                          } },

    'starting/loading_row'            => { enter       => '_load_row',
                                           transitions =>  { _on_load_row_done           => 'starting/updating_stats',
                                                             _on_load_row_bad_result     => 'stopping/clearing_runtime_row'    } },

    'starting/updating_stats'         => { enter       => '_incr_run_attempts',
                                           transitions =>  { _on_incr_run_attempts_done  => 'starting/searching_di',
                                                             _on_incr_run_attempts_bad_result => 'stopping/clearing_runtime_row'} },

    'starting/searching_di'           => { enter       => '_search_di',
                                           transitions => { _on_search_di_done           => 'starting/saving_runtime_row',
                                                            _on_search_di_bad_result     => 'stopping/clearing_runtime_row'     } },

    'starting/saving_runtime_row'     => { enter       => '_save_runtime_row',
                                           transitions => { _on_save_runtime_row_done    => 'starting/deleting_cmd',
                                                            _on_save_runtime_row_bad_result => 'stopping/clearing_runtime_row'  },
                                           ignore      => ['_on_save_runtime_row_result']                                        },

    'starting/deleting_cmd'           => { enter       => '_delete_cmd',
                                           transitions => { _on_delete_cmd_done          => 'starting/calculating_attrs'       } },

    'starting/calculating_attrs'      => { enter       => '_calculate_attrs',
                                           transitions => { _on_calculate_attrs_done     => 'starting/untaring_os_image'       } },

    'starting/untaring_os_image'      => { enter       => '_untar_os_image',
                                           transitions => { _on_untar_os_image_done      => 'starting/placing_os_image',
                                                            _on_untar_os_image_error     => 'stopping/clearing_runtime_row'     } },

    'starting/placing_os_image'       => { enter       => '_place_os_image',
                                           transitions => { _on_place_os_image_done      => 'starting/detecting_os_image_type',
                                                            _on_place_os_image_error     => 'stopping/clearing_runtime_row'     } },

    'starting/detecting_os_image_type'=> { enter       => '_detect_os_image_type',
                                           transitions => { _on_detect_os_image_type_done  => 'starting/killing_old_lxc',
                                                            _on_detect_os_image_type_error => 'stopping/clearing_runtime_row'   } },

    'starting/killing_old_lxc'        => { enter       => '_kill_lxc',
                                           transitions => { _on_kill_lxc_done            => 'starting/destroying_old_lxc',
                                                            _on_kill_lxc_error           => 'zombie/beating_to_death'          } },

    'starting/destroying_old_lxc'     => { enter       => '_destroy_lxc',
                                           transitions => { _on_destroy_lxc_done         => 'starting/allocating_os_overlayfs' } },

    'starting/allocating_os_overlayfs'=> { enter       => '_allocate_os_overlayfs',
                                           transitions => { _on_allocate_os_overlayfs_done  => 'starting/allocating_os_rootfs',
                                                            _on_allocate_os_overlayfs_error => 'stopping/clearing_runtime_row' } },

    'starting/allocating_os_rootfs'   => { enter       => '_allocate_os_rootfs',
                                           transitions => { _on_allocate_os_rootfs_done  => 'starting/allocating_home_fs',
                                                            _on_allocate_os_rootfs_error => 'stopping/unmounting_filesystems' } },

    'starting/allocating_home_fs'     => { enter       => '_allocate_home_fs',
                                           transitions => { _on_allocate_home_fs_done    => 'starting/creating_lxc',
                                                            _on_allocate_home_fs_error   => 'stopping/unmounting_filesystems' } },

    'starting/creating_lxc'           => { enter       => '_create_lxc',
                                           transitions => { _on_create_lxc_done          => 'starting/configuring_lxc',
                                                            _on_create_lxc_error         => 'stopping/destroying_lxc' } },

    'starting/configuring_lxc'        => { enter       => '_configure_lxc',
                                           transitions => { _on_configure_lxc_done       => 'starting/running_prestart_hook',
                                                            _on_configure_lxc_error      => 'stopping/destroying_lxc' } },

    'starting/running_prestart_hook'  => { enter       => '_run_prestart_hook',
                                           transitions => { _on_run_hook_done            => 'starting/launching',
                                                            _on_run_hook_error           => 'stopping/running_poststop_hook' } },

    #'starting/setting_fw_rules'       => { enter       => '_set_fw_rules',
    #                                       transitions => { _on_set_fw_rules_done        => 'starting/enabling_iface',
    #                                                        _on_set_fw_rules_error       => 'failing/unmounting_filesystems' } },

    'starting/launching'              => { enter       => '_start_lxc',
                                           transitions => { _on_start_lxc_done           => 'starting/waiting_for_vma',
                                                            _on_start_lxc_error          => 'stopping/running_poststop_hook' } },

    'starting/waiting_for_vma'        => { enter       => '_start_vma_monitor',
                                           leave       => '_stop_vma_monitor',
                                           transitions => { _on_alive                    => 'running/saving_state',
                                                            _on_dead                     => 'stopping/stopping_lxc',
                                                            _on_goto_debug               => 'debugging/saving_state',
                                                            _on_stop_cmd                 => 'stopping/deleting_cmd',
                                                            on_hkd_stop                 => 'stopping/powering_off',
                                                            _on_lxc_done                 => 'stopping/destroying_lxc' } },

    'running/saving_state'            => { enter       => '_save_state',
                                           transitions => { _on_save_state_done          => 'running/updating_stats',
                                                            # _on_save_state_done          => 'running/monitoring',
                                                            _on_save_state_bad_result    => 'stopping/powering_off' },
                                           delay       => [qw(_on_lxc_done)]                                                    },

    'running/updating_stats'          => { enter       => '_incr_run_ok',
                                           transitions =>  { _on_incr_run_ok_done        => 'running/running_poststart_hook',
                                                             _on_incr_run_ok_bad_result  => 'running/running_poststart_hook' },
                                           delay       => [qw(_on_lxc_done)],
                                           ignore      => [qw(_on_incr_run_ok_result)] },

    'running/running_poststart_hook'  => { enter       => '_run_poststart_hook',
                                           transitions => { _on_run_hook_done            => 'running/monitoring',
                                                            _on_run_hook_error           => 'stopping/powering_off' },
                                           delay       => [qw(_on_lxc_done)] },

    'running/monitoring'              => { enter       => '_start_vma_monitor',
                                           leave       => '_stop_vma_monitor',
                                           transitions => { _on_cmd_stop                 => 'stopping/deleting_cmd',
                                                            on_hkd_stop                  => 'stopping/powering_off',
                                                            _on_dead                     => 'stopping/stopping_lxc',
                                                            _on_goto_debug               => 'debugging/saving_state',
                                                            _on_lxc_done                 => 'stopping/killing_lxc' } },

    'debugging/saving_state'          => { enter       => '_save_state',
                                           transitions => { _on_save_state_done          => 'debugging/waiting_for_vma',
                                                            _on_save_state_bad_result    => 'stopping/powering_off'          },
                                           delay       => [qw(_on_lxc_done)]                                                   },

    'debugging/waiting_for_vma'       => { enter       => '_start_vma_monitor',
                                           leave       => '_stop_vma_monitor',
                                           transitions => { _on_alive                    => 'running/saving_state',
                                                            _on_cmd_stop                 => 'stopping/deleting_cmd',
                                                            on_hkd_stop                  => 'stopping/powering_off',
                                                            _on_lxc_done                 => 'stopping/killing_lxc' },
                                           ignore      => [qw(_on_dead
                                                              _on_goto_debug)] },

    'stopping/deleting_cmd'           => { enter       => '_delete_cmd',
                                           transitions => { _on_delete_cmd_done          => 'stopping/powering_off'           } },

    'stopping/powering_off'           => { enter       => '_poweroff',
                                           leave       => '_abort_all',
                                           transitions => { _on_rpc_poweroff_error       => 'stopping/stopping_lxc',
                                                            _on_lxc_done                 => 'stopping/destroying_lxc',
                                                            _on_rpc_poweroff_result      => 'stopping/waiting_for_lxc_to_exit'} },

    'stopping/waiting_for_lxc_to_exit'=> { enter       => '_set_state_timer',
                                           leave       => '_abort_all',
                                           transitions => { _on_lxc_done                 => 'stopping/killing_lxc',
                                                            _on_state_timeout            => 'stopping/stopping_lxc'           } },

    'stopping/stopping_lxc'           => { enter       => '_stop_lxc',
                                           transitions => { _on_stop_lxc_done            => 'stopping/waiting_for_lxc_to_stop'} },

    'stopping/waiting_for_lxc_to_stop'=> { enter       => '_set_state_timer',
                                           leave       => '_abort_all',
                                           transitions => { _on_lxc_done                 => 'stopping/killing_lxc',
                                                            _on_state_timeout            => 'stopping/killing_lxc'            } },

    'stopping/killing_lxc'            => { enter       => '_kill_lxc',
                                           transitions => { _on_kill_lxc_done            => 'stopping/running_poststop_hook',
                                                            _on_kill_lxc_error           => 'zombie/beating_to_death'         },
                                           ignore      => ['_on_lxc_done']                                                      },

    'stopping/running_poststop_hook'  => { enter       => '_run_poststop_hook',
                                           transitions => { _on_run_hook_done            => 'stopping/destroying_lxc',
                                                            _on_run_hook_error           => 'stopping/destroying_lxc'         } },

    'stopping/destroying_lxc'         => { enter       => '_destroy_lxc',
                                           transitions => { _on_destroy_lxc_done         => 'stopping/unmounting_filesystems' } },

    'stopping/unmounting_filesystems' => { enter       => '_unmount_filesystems',
                                           transitions => { _on_unmount_filesystems_done  => 'stopping/clearing_runtime_row',
                                                            _on_unmount_filesystems_error => 'zombie/beating_to_death'        } },

    'stopping/clearing_runtime_row'   => { enter       => '_clear_runtime_row',
                                           transitions => { _on_clear_runtime_row_done   => 'stopped',
                                                            _on_clear_runtime_row_error  => 'zombie/beating_to_death'         } },

    'stopped'                         => { enter       => '_call_on_stopped'                                                    },

    'zombie/beating_to_death'         => { jump        => 'zombie/saving_state'                                                   },

    'zombie/saving_state'             => { enter       => '_save_state',
                                           transitions => { _on_save_state_done          => 'zombie/calculating_attrs',
                                                            _on_save_state_error         => 'zombie/calculating_attrs',       } },

    'zombie/calculating_attrs'        => { enter       => '_calculate_attrs',
                                           transitions => { _on_calculate_attrs_done     => 'zombie/stopping_lxc'            } },

    'zombie/stopping_lxc'             => { enter       => '_stop_lxc',
                                           transitions => { _on_stop_lxc_done            => 'zombie/waiting_for_lxc_to_stop' } },

    'zombie/waiting_for_lxc_to_stop'  => { enter       => '_wait_for_zombie_lxc',
                                           transitions => { _on_wait_for_zombie_lxc_done => 'zombie/killing_lxc'             } },

    'zombie/killing_lxc'              => { enter       => '_kill_lxc',
                                           transitions => { _on_kill_lxc_done            => 'zombie/destroying_lxc',
                                                            _on_kill_lxc_error           => 'zombie'                         } },

    'zombie/destroying_lxc'           => { enter       => '_destroy_lxc',
                                           transitions => { _on_destroy_lxc_done         => 'zombie/unmounting_filesystems'  } },

    'zombie/unmounting_filesystems'   => { enter       => '_unmount_filesystems',
                                           transitions => { _on_unmount_filesystems_done => 'zombie/clearing_runtime_row',
                                                            _on_unmount_filesystems_error=> 'zombie'                         } },

    'zombie/clearing_runtime_row'     => { enter       => '_clear_runtime_row',
                                           transitions => { _on_clear_runtime_row_done   => 'stopped',
                                                            _on_clear_runtime_row_error  => 'zombie'                         } },

    'zombie'                          => { enter       => '_set_state_timer',
                                           leave       => '_abort_all',
                                           transitions => { _on_state_timeout => 'zombie/killing_lxc',
                                                            on_hkd_stop => 'stopped'                                         } };

#sub leave_state :OnState('starting/waiting_for_vma') {
#    my ($self, undef, $target) = @_;
#    $debug and $self->_debug("leave_state target: $target");
#    unless ($target =~ /^running/) {
#        $self->_stop_vma_monitor;
#    }
#}

sub _on_cmd_stop  :OnState('__any__') { shift->delay_until_next_state }
sub _on_cmd_start :OnState('__any__') { shift->_maybe_callback('on_delete_cmd') }

sub on_hkd_stop  :OnState('__any__') { shift->delay_until_next_state }

sub _mkpath {
    my ($path, $mask) = @_;
    $mask ||= 0755;
    my @dirs;
    my @parts = File::Spec->splitdir(File::Spec->rel2abs($path));
    while (@parts) {
        my $dir = File::Spec->join(@parts);
        if (-d $dir) {
            -d $_ or mkdir $_, $mask or return for @dirs;
            return -d $path;
        }
        unshift @dirs, $dir;
        pop @parts;
    }
    return;
}

sub _calculate_attrs {
    my $self = shift;
    $self->{lxc_name} = "qvd-$self->{vm_id}";

    my $rootfs_parent = $self->_cfg('path.storage.rootfs');
    $rootfs_parent =~ s|/*$|/|;
    $self->{os_rootfs_parent} = $rootfs_parent;
    $self->{os_rootfs} = "$rootfs_parent$self->{vm_id}-fs";

    if (defined $self->{di_path}) {
        # this sub is called with just the vm_id loaded into the
        # object when reaping zombie containers
        my $basefs_parent = $self->_cfg('path.storage.basefs');
        $basefs_parent =~ s|/*$|/|;
        # note that os_basefs may be changed later from
        # _detect_os_image_type!
        $self->{os_basefs} = "$basefs_parent/$self->{di_path}";

        # FIXME: use a better policy for overlay allocation
        my $overlays_parent = $self->_cfg('path.storage.overlayfs');
        $overlays_parent =~ s|/*$|/|;
        $self->{os_overlayfs} = $overlays_parent . join('-', $self->{di_id}, $self->{vm_id}, 'overlayfs');
        unless ($self->_cfg('vm.overlay.persistent')) {
            $self->{os_overlayfs_old} = $overlays_parent . join('-',
                                                                'deleteme', $self->{di_id}, $self->{vm_id},
                                                                $$, rand(100000));
        }
    }

    if ($self->{user_storage_size}) {
        my $homefs_parent = $self->_cfg('path.storage.homefs');
        $homefs_parent =~ s|/*$|/|;
        $self->{home_fs} = "$homefs_parent$self->{vm_id}-fs";

        $self->{home_fs_mnt} = "$self->{os_rootfs}/home";
    }

    if ($debug) {
        for (qw(di_path os_basefs os_overlayfs os_overlayfs_old os_rootfs_parent os_rootfs home_fs home_fs_mnt)) {
            my $path = $self->{$_} // '<undef>';
            $self->_debug("path $_: $path");
        }
    }

    $self->_on_calculate_attrs_done;
}

sub _untar_os_image {
    my $self = shift;
    my $image_path = $self->_cfg('path.storage.images') . '/' . $self->{di_path};
    unless (-f $image_path) {
        ERROR "Image $image_path attached to VM $self->{vm_id} does not exist on disk";
        return $self->_on_untar_os_image_error;
    }
    my $basefs = $self->{os_basefs};
    -d $basefs and return $self->_on_untar_os_image_done;
    my $tmp = $self->_cfg('path.storage.basefs') . "/untar-$$-" . rand(100000);
    $tmp++ while -e $tmp;
    unless (_mkpath $tmp) {
        ERROR "Unable to create directory $tmp";
        return $self->_on_untar_os_image_error;
    }
    $self->{os_basefs_tmp} = $tmp;

    my @cmd = ( $self->_cfg('command.tar'),
                'x',
                -f => $image_path,
                -C => $tmp );
    push @cmd, '-z' if $image_path =~ /\.(?:tgz|gz)$/;
    push @cmd, '-j' if $image_path =~ /\.(?:tbz|bz2)$/;

    $self->_run_cmd(\@cmd);
}

sub _place_os_image {
    my $self = shift;
    my $basefs = $self->{os_basefs};
    -d $basefs and return $self->_on_place_os_image_done;
    my $tmp = $self->{os_basefs_tmp};
    rename $tmp, $basefs
        or ERROR "rename of $tmp to $basefs failed: $!";
    unless (-d $basefs) {
        ERROR "$basefs does not exist or is not a directory";
        return $self->_on_place_os_image_error;
    }
    $self->_on_place_os_image_done;
}

sub _detect_os_image_type {
    my $self = shift;
    my $basefs = $self->{os_basefs};
    if (-d "$basefs/sbin/") {
        # FIXME: improve autodetection logic
        $debug and $self->_debug("os image is of type basic");
    }
    elsif (-d "$basefs/rootfs/sbin/") {
        $self->{os_meta} = $basefs;
        $self->{os_basefs} = "$basefs/rootfs";
        $debug and $self->_debug("os image is of type extended");
    }
    else {
        ERROR "sbin not found at $basefs/sbin or at $basefs/rootfs/sbin";
        return $self->_on_detect_os_image_type_error;
    }
    return $self->_on_detect_os_image_type_done;
}

sub _allocate_os_overlayfs {
    my $self = shift;
    my $overlayfs = $self->{os_overlayfs};
    my $overlayfs_old =  $self->{os_overlayfs_old};
        if (-d $overlayfs) {
        if (defined $overlayfs_old) {
            $debug and $self->_debug("deleting old overlay directory");
            unless (rename $overlayfs, $overlayfs_old) {
                ERROR "Unable to move old $overlayfs out of the way to $overlayfs_old";
                return $self->_on_allocate_os_overlayfs_error;
            }
        }
        else {
            $debug and $self->_debug("reusing old overlay directory");
            return $self->_on_allocate_os_overlayfs_done
        }
    }
    unless (_mkpath $overlayfs) {
        ERROR "Unable to create overlay file system $overlayfs: $!";
        return $self->_on_allocate_os_overlayfs_error;
    }
    $self->_on_allocate_os_overlayfs_done;
}

sub _allocate_os_rootfs {
    my $self = shift;
    my $rootfs = $self->{os_rootfs};
    unless (_mkpath $rootfs) {
        ERROR "unable to create directory $rootfs";
        return $self->_on_allocate_os_rootfs_error;
    }
    system $self->_cfg('command.umount'), $rootfs; # just in case!
    $debug and $self->_debug("rootfs: $rootfs, rootfs_parent: $self->{os_rootfs_parent}");
    if ((stat $rootfs)[0] != (stat $self->{os_rootfs_parent})[0]) {
        ERROR "a file system is already mounted on top of $rootfs";
        return $self->_on_allocate_os_rootfs_error;
    }

    my $unionfs_type = $self->_cfg('vm.lxc.unionfs.type');

    given ($unionfs_type) {
        when('aufs') {
            if (system $self->_cfg('command.mount'),
                -t => 'aufs',
                -o => "br:$self->{os_overlayfs}:$self->{os_basefs}=ro", "aufs", $rootfs) {
                ERROR "unable to mount aufs (code: " . ($?>>8) . ")";
                return $self->_on_allocate_os_rootfs_error;
            }
        }
        when ('unionfs-fuse') {
            if (system $self->_cfg('command.unionfs-fuse'),
                -o => 'cow',
                -o => 'max_files=32000',
                -o => 'suid',
                -o => 'dev',
                -o => 'allow_other',
                "$self->{os_overlayfs}=RW:$self->{os_basefs}=RO", $rootfs) {
                ERROR "unable to mount unionfs-fuse (code: " . ($? >> 8) . ")";
                return $self->_on_allocate_os_rootfs_error;
            }
        }
        when ('bind') {
            if (system $self->_cfg('command.mount'),
                '--bind' => $self->{os_basefs}, $rootfs) {
                ERROR "unable to mount bind $self->{os_basefs} into $rootfs (code: " . ($? >> 8) . ")";
                return $self->_on_allocate_os_rootfs_error;
            }
        }
        default {
            ERROR "unsupported unionfs type $unionfs_type";
            return $self->_on_allocate_os_rootfs_error;
        }
    }
    $self->_on_allocate_os_rootfs_done;
}

sub _allocate_home_fs {
    my $self = shift;

    my $homefs = $self->{home_fs};
    defined $homefs or return $self->_on_allocate_home_fs_done;

    unless (_mkpath $homefs) {
        ERROR "unable to create directory $homefs";
        return $self->_on_allocate_home_fs_error;
    }
    my $mount_point = $self->{os_homefs_mnt};
    unless (_mkpath $mount_point) {
        ERROR "unable to create directory $mount_point";
        return $self->_on_allocate_home_fs_error;
    }

    # let lxc mount the home file system for us
    $self->{home_fstab} = "$homefs $mount_point none defaults,bind";
    #    if (system $self->_cfg('command.mount'), '--bind', $homefs, $mount_point) {
    #        ERROR "unable to bind $homefs into $mount_point, mount failed (code: ".($?>>8).")";
    #        return $self->_on_allocate_os_rootfs_error;
    #    }

    $self->_on_allocate_home_fs_done
}

sub _create_lxc {
    my $self = shift;
    my $lxc_name = $self->{lxc_name};

    my ($fh, $fn) = tempfile(UNLINK => 0);
    $debug and $self->_debug("saving lxc configuration to $fn");
    my $bridge = $self->_cfg('vm.network.bridge');
    my $console;
    if ($self->_cfg('vm.serial.capture')) {
        my $captures_dir = $self->_cfg('path.serial.captures');
        mkdir $captures_dir, 0700;
        if (-d $captures_dir) {
            my @t = gmtime; $t[5] += 1900; $t[4] += 1;
            my $ts = sprintf("%04d-%02d-%02d-%02d:%02d:%2d-GMT0", @t[5,4,3,2,1,0]);
            $console = "$captures_dir/capture-$self->{name}-$ts.txt";
        }
        else {
            ERROR "Unable to create captures directory $captures_dir";
            return $self->_on_create_lxc_error;
        }
    }
    else {
        $console = '/dev/null';
    }

    my $pair = $self->_cfg('vm.network.device.prefix') . $self->{vm_id};
    
    my ($r1, $r2) = map int rand 10000, 0..1;
    
    # FIXME: make this template-able or configurable in some way
    print $fh <<EOC;
lxc.network.type=veth
lxc.network.veth.pair=${pair}r$r1
lxc.network.name=eth0
lxc.network.flags=up
lxc.network.hwaddr=$self->{mac}
lxc.network.link=$bridge
lxc.console=$console
lxc.tty=3
lxc.rootfs=$self->{os_rootfs}
lxc.mount.entry=$self->{home_fstab}
#lxc.cap.drop=sys_module audit_control audit_write linux_immutable mknod net_admin net_raw sys_admin sys_boot sys_resource sys_time

EOC
    close $fh;
    $self->_run_cmd([$self->_cfg('command.lxc-create'),
                     -n => $lxc_name,
                     -f => $fn]);
}

sub _configure_lxc {
    # FIXME: anything to do here?
    shift->_on_configure_lxc_done
}

sub _start_lxc {
    my $self = shift;
    $self->{lxc_pid} = $self->_run_cmd([$self->_cfg('command.lxc-start'), -n => $self->{lxc_name}],
                                       ignore_errors => 1,
                                       on_done => sub {
                                           delete $self->{lxc_pid};
                                           $self->_on_lxc_done;
                                       });
    $self->_on_start_lxc_done;
}

sub _stop_lxc {
    my $self = shift;
    system ($self->_cfg('command.lxc-stop'), -n => $self->{lxc_name});
    $self->_on_stop_lxc_done;
}

sub _wait_for_zombie_lxc {
    # FIXME: implement me!
    shift->_on_wait_for_zombie_lxc_done
}

sub _kill_lxc {
    my $self = shift;
    my @pids;
    my $cgroup = $self->_cfg('path.cgroup');
    my $fn = "$cgroup/$self->{lxc_name}/cgroup.procs";
    if (open my $fh, '<', $fn) {
        chomp(@pids = <$fh>);
    }
    else {
        $debug and $self->_debug("unable to open $fn: $!");
    }
    my $lxc_pid = $self->{lxc_pid};
    push @pids, $lxc_pid if defined $lxc_pid;
    if (@pids) {
        $debug and $self->_debug("killing zombie processes and then trying again, pids: @pids");
        if ($self->{killer_count}++ > $self->_cfg('internal.hkd.lxc.killer.retries')) {
            $debug and $self->_debug("too many retries, no more killing, peace!");
            $self->_abort_cmd($lxc_pid);
            return $self->_on_kill_lxc_error;
        }
        kill KILL => @pids;
        $self->_call_after(2 => '_kill_lxc');
    }
    else {
        $debug and $self->_debug("all processes killed");
        return $self->_on_kill_lxc_done;
    }
}

sub _destroy_lxc {
    my $self = shift;
    $self->_run_cmd([$self->_cfg('command.lxc-destroy'), -n => $self->{lxc_name}],
                    ignore_errors => 1);
}

sub _unmount_filesystems {
    my $self = shift;
    $self->{unmounted} //= {};
    my $rootfs = $self->{os_rootfs};
    my $mi = Linux::Proc::Mountinfo->read;
    if (my $at = $mi->at($rootfs)) {
        my @mnts = map $_->mount_point, @{$at->flatten};
        my @remaining = grep !$self->{unmounted}, @mnts;
        if (@remaining) {
            my $next = $remaining[-1];
            $self->{unmounted}{$next} = 1;
            return $self->_unmount_filesystem($next);
        }
        else {
            ERROR "Some filesystems could not be unmounted: @mnts";
            $debug and $self->_debug("Some filesystems could not be unmounted: @mnts");
            delete $self->{unmounted};
            return $self->_on_unmount_filesystems_error;
        }
    }
    else {
        $debug and $self->_debug("No filesystem mounted at $rootfs found");
    }
    $self->_on_unmount_filesystems_done
}

sub _unmount_filesystem {
    my ($self, $mnt) = @_;
    $self->_run_cmd([$self->_cfg('command.umount'), $mnt],
                    timeout => $self->_cfg('internal.hkd.lxc.killer.umount.timeout'),
                    ignore_errors => 1,
                    on_done => '_unmount_filesystems');
}

sub _delete_cmd {
    my $self = shift;
    $self->_maybe_callback('on_delete_cmd');
    $self->_on_delete_cmd_done;
}

sub _run_prestart_hook { shift->_run_hook('prestart') }
sub _run_poststart_hook { shift->_run_hook('poststart') }
sub _run_poststop_hook { shift->_run_hook('poststop') }

sub _run_hook {
    my ($self, $name) = @_;
    my $meta = $self->{os_meta};
    if (defined $meta) {
        my $hook = "$meta/hooks/$name";
        if (-f $hook) {
            my @args = ( id    => $self->{vm_id},
                         hook  => $name,
                         state => $self->_main_state,
                         map { $_ => $self->{$_} } qw( use_overlay
                                                       os_meta
                                                       mac
                                                       name
                                                       ip
                                                       os_rootfs
                                                       os_overlayfs
                                                       lxc_name ));

            $debug and $self->_debug("running hook $hook for $name");
            return $self->_run_cmd([$hook => @args],
                                   save_old_watcher => 1);
        }
    }
    $debug and $self->_debug("no hook for $name");
    $self->_on_run_hook_done;
}

1;
