package QVD::Config::Core;

use strict;
use warnings;

use Config::Properties;
use IO::Scalar;
use QVD::Config::Core::OS;

my %os = QVD::Config::Core::OS::detect_os;
my @tags = ("$os{os}",
            "$os{os}-$os{version}",
            "$os{os}-$os{version}.$os{revision}");

my @data;
while (<DATA>) {
    if (s/^\@([\w\-+\.]+)\@\s*//) {
        next unless grep $1 eq $_, @tags;
    }
    push @data, $_;
}

my $data = join('', @data);
my $fh = IO::Scalar->new(\$data);
our $defaults = Config::Properties->new;
$defaults->load($fh);

$defaults->setProperty('config.os', $os{os});
$defaults->setProperty('config.os.version', $os{version});
$defaults->setProperty('config.os.revision', $os{revision});

1;

__DATA__

## name of this machine
# nodename =

## database connection details
database.host = localhost
database.user = qvd
database.name = qvd
# database.password =

model.user.login.case-sensitive = 0

## directory where several configuration, state, pid and certificate files are stored
path.run = /var/run/qvd
## where QVD logs are stored
path.log = /var/log
## temporary files
path.tmp = /var/tmp
## main storage location for OS images (both KVM and LXC)
path.storage.root = /var/lib/qvd/storage
## OS images ready to be used
path.storage.staging = ${path.storage.root}/staging
## OS images in use by some VM
path.storage.images = ${path.storage.root}/images

# storage directories for KVM
path.storage.overlays = ${path.storage.root}/overlays
path.storage.homes = ${path.storage.root}/homes
path.storage.check = ${path.storage.homes}/.rw_check

# storage directories for LXC
path.storage.basefs = ${path.storage.root}/basefs
path.storage.homefs = ${path.storage.root}/homefs
path.storage.btrfs.root = ${path.storage.root}

path.run.lxc = ${path.run}/lxc

path.storage.overlayfs = ${path.storage.btrfs.root}/overlayfs
path.storage.rootfs = ${path.storage.btrfs.root}/rootfs

# storage datasets for LXC-ZFS
path.storage.zfs.root = ${path.storage.root}

# zpool name for zfs
storage.zpool.name = qvd

## paths for SSL certificates and CAs
path.l7r.ssl = ${path.run}/l7r/ssl
path.l7r.ssl.key = ${path.l7r.ssl}/key.pem
path.l7r.ssl.cert = ${path.l7r.ssl}/cert.pem
path.l7r.ssl.ca = ${path.l7r.ssl}/ca.pem
path.l7r.ssl.crl = ${path.l7r.ssl}/crl.pem

# Semicolon separated paths in path.ssl.ca.system.path only
# SYSTEM_DEFAULT is a special value that invokes autodetection

path.ssl.ca.system.path = SYSTEM_DEFAULT:/System/Library/OpenSSL/certs/
path.ssl.ca.system.file = SYSTEM_DEFAULT

path.ssl.ca.personal = certs


## KVM serial port captures or LXC console output
path.serial.captures = ${path.tmp}/qvd
path.hypervisor.captures = ${path.tmp}/qvd

path.cgroup = /sys/fs/cgroup
# path.cgroup.cpu.lxc = ${path.cgroup}/cpu/lxc

path.client.pixmaps = pixmaps
path.client.pixmaps.alt = /usr/share/pixmaps

path.qvd.bin = /usr/lib/qvd/bin
path.usb.database = /usr/share/hwdata/usb.ids

## paths to external executables
command.kvm = kvm
command.kvm-img = qemu-img
command.sshfs = ${path.qvd.bin}/sshfs
command.open_file = /usr/bin/xdg-open
command.sftp-server = /usr/lib/openssh/sftp-server
command.nxagent = /usr/bin/nxagent
command.nxdiag = ${path.qvd.bin}/nxdiag.pl
command.x-session = /etc/X11/Xsession
command.brctl = /sbin/brctl
command.ifconfig = /sbin/ifconfig
command.dhcpd = /usr/sbin/dnsmasq
command.useradd = /usr/sbin/useradd
command.userdel = /usr/sbin/userdel
command.groupadd = /usr/sbin/groupadd
command.groupdel = /usr/sbin/groupdel
command.tar = tar
command.umount = umount
command.mount = mount
command.version.mount.overlayfs = 2
command.rm = rm
command.unionfs-fuse = ${path.qvd.bin}/unionfs
command.lxc-destroy = ${path.qvd.bin}/lxc-destroy
command.lxc-console = ${path.qvd.bin}/lxc-console
command.lxc-create = ${path.qvd.bin}/lxc-create
command.lxc-start = ${path.qvd.bin}/lxc-start
command.lxc-stop = ${path.qvd.bin}/lxc-stop
command.lxc-wait = ${path.qvd.bin}/lxc-wait
command.version.lxc = 0.7
command.ebtables = ebtables
command.iptables = iptables
command.modprobe = /sbin/modprobe
command.xinit = /usr/bin/xinit
command.xhost = /usr/bin/xhost
command.xhost.family = si
command.nxproxy = /usr/bin/nxproxy
command.btrfs = /sbin/btrfs
command.ip = /sbin/ip
command.x11vnc = /usr/bin/x11vnc
command.qvd-l7r-slave = ${path.qvd.bin}/qvd-l7r-slave
command.windows.xming = Xming\\Xming.exe
command.windows.vcxsrv = VcxSrv\\vcxsrv.exe
command.windows.pulseaudio = pulseaudio\\pulseaudio.exe
command.windows.nxproxy = nx\\nxproxy.exe
command.windows.sftp-server = bin/sftp-server.exe

command.nxagent.args.extra =
command.x-session.args.extra =
command.sftp-server = /usr/lib/openssh/sftp-server

command.qvd-lxc-autodev = ${path.qvd.bin}/qvd-lxc-autodev

command.darwin.x11 = XQuartz.app
command.darwin.nxproxy = bin/nxproxy
command.darwin.pulseaudio = bin/pulseaudio
command.darwin.sftp-server = /usr/libexec/sftp-server

command.usbsrv = /usr/local/bin/usbsrv
command.usbclnt = /usr/local/bin/usbclnt
command.usbip = /usr/bin/usbip
command.slaveclient = ${path.qvd.bin}/qvd-slaveclient

# zfs commands
command.zfs = /sbin/zfs
command.zpool = /sbin/zpool

## whether to remember password after successful connection
client.remember_password = 0

## whether to remember the username after a successful connection
client.remember_username = 1

## whether to show the previous checkbox or not
client.show.remember_password = 0

## whether to show the settings tab
client.show.settings = 1

## nxproxy's link parameter, can be: modem, isdn, adsl, wan, lan, local or a bandwidth specification (56k, 1m, 100m...)
client.link = adsl

## Extra arguments to nxproxy.
client.nxproxy.extra_args =

## Extra arguments to nxagent. Allows non-standard configurations, like defining custom link types.
## Sent to the VM side and applied there.
client.nxagent.extra_args =

## Extra arguments for sshfs. These have been determined as reasonable defaults.
client.sshfs.extra_args=-o atomic_o_trunc -o idmap=user

## Extra arguments for Windows X servers
client.xming.extra_args=-multiwindow -notrayicon -nowinkill -clipboard +bs -wm
client.vcxsrv.extra_args=-rootless -notrayicon -nowinkill -clipboard +bs -wm -listen tcp -silent-dup-error -ac -nomultimonitors

## nxproxy's geometry parameter
client.geometry = 1024x768
## nxproxy's fullscreen parameter
client.fullscreen =
## enable the Pulse audio server in the client
client.audio.enable =
## something regarding an NX channel
client.printing.enable = 1
## L7R port the client should connect to
client.host.port = 8443
## L7R host the client should connect to
client.host.name =
## user name for client authentication
client.user.name =
## user password for client authentication
client.user.password =
## Auto connect when the client is invoked
client.auto_connect = 0
## whether to use SSL in the client↔server communication or not
client.use_ssl = 1
client.ssl.use_cert = 0

### Internal SSL options. These get passed directly to QVD::HTTPC.
### See the full list in HTTPC.pm and the documentation in 
### IO::Socket::SSL.
###
### Using these is discouraged. Most are internal SSL options, and
### some are overriden by the client. This functionality exists to
### allow tweaking parameters that weren't intentionally exposed in
### the QVD client.
###
### Specifically, the client overrides hostname verification, so use
### the client.ssl.allow_bad_host option instead.
client.ssl.options.SSL_version = SSLv23:!SSLv3:!SSLv2:!TLSv1


##########################################################################
## Configurable security options
##########################################################################

## In this context, "allow" means "allow the user to decide".
##
## If set to 1, the user gets an error dialog that allows to continue
## If set to 0, the user gets an error dialog that is fatal.


## Allow certs that fail hostname verification. This is a serious
## error and a correct installation will not have it.
client.ssl.allow_bad_host=1

## Allow revoked certificates. EXTREMELY bad idea.
client.ssl.allow_revoked=0

## Allow untrusted certificates, such as those signed by unknown CAs
client.ssl.allow_untrusted=1

## Allow expired certificates
client.ssl.allow_expired=1

## Allow certificates that are not yet valid. Generally indicates a 
## local clock problem.
client.ssl.allow_not_yet_valid=1

## Allow certificates that use old, insecure signature algorithms:
## MD2, MD4, MD5 and SHA1
client.ssl.allow_insecure_sign_algo=1

## Allow certificates with a bit length <= 1024 bits.
## They're obsolete and shouldn't be used.
client.ssl.allow_weak_key=0

## Allow continuing in case of an unrecognized SSL error
client.ssl.allow_unknown_error=1

## Force user to wait this many seconds before allowing to accept
## the certificate. Set to 0 to disable.
client.ssl.error_timeout=5

## SSL_ocsp_mode in the IO::Socket::SSL manpage. The value is a list
## of the following, separated by a |
##     SSL_OCSP_NO_STAPLE
##         Don't ask the server to staple
##
##     SSL_OCSP_TRY_STAPLE
##         Try using OCSP stapling, but don't require it
##
##     SSL_OCSP_MUST_STAPLE
##         Require OCSP stapling, fail if the server does not provide it
##
##     SSL_OCSP_FAIL_HARD
##         Fail on errors other than a revoked certificate. A revoked cert
##         always causes a failure. Failures will be handled by the client
##         and shown to the user in the SSL warning window.
##
##         Not setting this option means that issues like OCSP server
##         malfunctions that make it impossible to verify the cert will be
##         silently ignored, and won't be shown to the user, nor appear in
##         the log file.
##
##     SSL_OCSP_FULL_CHAIN
##         Verify the full chain of certificates and not only the client one
##         Some OCSP servers like Comodo's fail with this option, so it is
##         discouraged for general use.
##
## Example:
## client.ssl.ocsp_mode = SSL_OCSP_MUST_STAPLE | SSL_OCSP_FULL_CHAIN

client.ssl.ocsp_mode=SSL_OCSP_TRY_STAPLE|SSL_OCSP_FAIL_HARD

## slave shell
client.slave.command = bin/qvd-client-slaveserver
client.slave.client = bin/qvd-slaveclient
# enable commands used for benchmarking and testing the functionality
# of the slave channel
client.slave.debug_commands = 0
## enable making slave connections to VM
client.slave.enable = 1
## force locale, ignoring system LC_* and LANG environment variables
client.locale =
## enable exporting $HOME, /media and /Volumes to the VM.
client.file_sharing.enable = 1

## On OSX the window is hard to resize if it's too large, so
## we check whether we should default to a lower window size

## Only do the check on the first start, and don't mess
## with it afterwards. Also saves startup time.
client.darwin.screen_resolution.verified = 0
## When the screen resolution is this or less, use the low geometry setting
client.darwin.screen_resolution.min=1440x900
## Geometry to use when the screen is low resolution
client.darwin.screen_resolution.low_res_geometry=800x600

# Enable USB sharing
client.usb.enable = 0
client.usb.implementation = USBIP
client.usb.sudo = 1
client.usb.usbip.port = 3240
client.usb.usbip.debug = 0
client.usb.usbip.log = 0

# Share all USB devices automatically (most of the time not a good idea)
client.usb.share_all = 0

# List of USB devices to share with the VM. 
# Syntax: VID:PID@serial, comma separated. Spaces are allowed. For example:
# 0441:0012, 1234:5678@12345678
client.usb.share_list =


## umask for the L7R process
l7r.user.umask = 0022
## whether L7R accepts SSL incoming connections or not
l7r.use_ssl = 1
## port the L7R should listen to
l7r.port = 8443
## IP addresses L7R should bind to/listen at
l7r.address = *
## actually usused in the code
# l7r.as_user = root
## unused!
l7r.pid_file = ${path.run}/l7r.pid
## authentication plugins to use. Comma-separated list of alphanumeric words. Example: "ldap, foo_43,default"
l7r.auth.plugins = default
l7r.auth.plugin.default.salt=qvd1234

## load balancing plugins to use. Similar to auth plugins
l7r.loadbalancer.plugin = default
## each plugin should document its own parameters
l7r.loadbalancer.plugin.default.weight.ram = 1
l7r.loadbalancer.plugin.default.weight.cpu = 1
l7r.loadbalancer.plugin.default.weight.random = 1

l7r.client.cert.require = 0

l7r.ssl.options.SSL_version = TLSv1_2:!SSLv3:!SSLv2:!TLSv1
l7r.ssl.options.SSL_cipher_list = HIGH:!aNULL:!MD5:!RC4:!3DES:!DES:!MEDIUM:!LOW:!EXPORT

## umask for the HKD process
hkd.user.umask = 0022
## user to run hkd as
hkd.as_user = root
## path to the hkd PID file
hkd.pid_file = ${path.run}/qvd-hkd.pid

## user to run l7r as
l7r.as_user = root
## path to the l7r PID file
l7r.pid_file = ${path.run}/qvd-l7r.pid


## username of the WAT administrator
wat.admin.login = admin
# wat.admin.password =

## path to the log file
log.filename = ${path.log}/qvd.log

## WAT logs go into its own file to avoid permission issues as the process is not run as root
wat.log.filename = ${path.log}/qvd-wat.log

## log verbosity (FATAL, ERROR, WARN, INFO, DEBUG or TRACE)
log.level = INFO

## these two seem to be unused
admin.ssh.opt.StrictHostKeyChecking = no
admin.ssh.opt.UserKnownHostsFile = /dev/null

## virtualization engine to use, either kvm or lxc
vm.hypervisor = kvm

## COW fs to use with LXC
vm.lxc.unionfs.type = overlayfs
# vm.lxc.unionfs.type = unionfs-fuse
vm.lxc.unionfs.bind.ro = 1

internal.vm.lxc.conf.extra=

## whether to keep overlay images from one session to the next
vm.overlay.persistent = 0
## use KVM's virtio capabilities
vm.kvm.virtio = 1

## Number of container processors
vm.lxc.cpuset.size = 4
# vm.lxc.cpuset.available =

## Virtual machines number of CPUs
vm.kvm.cpus = 2

## these two specify the VNC availability and options for KVM's VNC support
vm.vnc.redirect = 0
vm.vnc.opts =
## whether to use KVM's serial support or not
vm.serial.redirect = 1
## capture serial port traffic to a file
## - in KVM it is ignored if serial port is redirected (ie if vm.serial.redirect is set to 1)
## - in LXC it saves the capture under the directory specified in path.serial.captures
vm.serial.capture = 0

vm.hypervisor.capture = 0

## all VMs will be attached to this interface, which must be a bridge
## the DHCP server uses this setting too
vm.network.bridge = qvdnet

# Default search domain for virtual machines
vm.network.domain=

## for LXC's lxc.network.veth.pair parameter
internal.vm.network.device.prefix = qvd
## start of DHCP range. There's no sensible default value
# vm.network.ip.start=10.0.0.100

## QVD private network netmask. There's no sensible default value
# vm.network.ip.netmask=255.255.0.0

vm.network.use_dhcp = 1

# high bytes of the MAC address, the IP is used for the low bytes.
vm.network.mac.prefix = 54:52:00

## file to pass to dnsmasq at its --dhcp-hostsfile parameter
internal.vm.network.dhcp-hostsfile=${path.run}/dhcp-hostsfile

# enable firewall rules
internal.vm.network.firewall.enable = 1
vm.network.firewall.nat.iface =

## not sure about this one
internal.vm.debug.enable = 0


## default values for newly created OSFs
osf.default.memory = 256
osf.default.overlay = 1

## so that the VMA exports PULSE_SERVER before xinit invocation and passes the 'media=1' parameter to nxagent
vma.audio.enable = 0
## enables "slave channel" in nxagent
vma.slave.enable = 0
## slave shell to execute to client requests
vma.slave.command = ${path.qvd.bin}/qvd-vma-slaveserver
## enables the printing channel in nxagent
vma.printing.enable = 0
## path to the VMA PID file
vma.pid_file = /var/run/qvd/vma.pid

## KVM: disk drive will be visible as: 0=hda, 1=hdb, 2=hdc... (parameter 'index' within -drive in KVM)
vm.kvm.home.drive.index = 1
## optional: device that contains the homes, as seen from within the VM
vma.user.home.drive = /dev/vdb
## when autoprovisioning homes, filesystem type to create in the device
vma.user.home.fs = ext4
## where to mount the homes device
vma.user.home.path = /home
## default user name and groups it will belong to
vma.user.default.name = qvd
vma.user.default.groups =
vma.default.lang = en_US.UTF-8
vma.usb.usbip.debug = 0
vma.usb.usbip.log = 0
vma.sshfs.extra_args = -o idmap=user -o atomic_o_trunc

# When using LXC if this flag is set, QVD will assume that the home
# directories are not per virtual machine but per user and that they
# follow the typical NFS home structure.
# Note that in order for this schema to work, the user ids used on the
# containers and in the directories shouls match. This is usually
# atained using an authentication plugin (i.e. LDAP) that assigns a UID
# that is the same used on the NFS.
vm.lxc.home.per.user = 0

## umask for the VMA
vma.user.umask = 0022

## shell for user
vma.user.shell = /bin/bash

## external executables the VMA calls when some events happen
vma.on_action.pre-connect =
vma.on_action.connect =
vma.on_action.stop =
vma.on_action.disconnect =
vma.on_action.suspend =
vma.on_action.poweroff =
vma.on_action.expire =

## external executables the VMA calls just before some states are entered
vma.on_state.connected =
vma.on_state.suspended =
vma.on_state.disconnected =

## external executables the VMA calls during user provisioning
vma.on_provisioning.mount_home =
vma.on_provisioning.add_user =
vma.on_provisioning.after_add_user =

## both unused
vma.default.client.keyboard = pc105/en
vma.default.client.link = adsl

## unused
hkd.vm.starting.max = 6

# internal parameters, do not change!!!
internal.l7r.timeout.vm_start = 270
internal.l7r.timeout.vm_stop = 270
internal.l7r.timeout.x_start = 10
internal.l7r.timeout.vma = 4
internal.l7r.timeout.takeover = 30
internal.l7r.retry.x_start = 20
internal.l7r.poll_time.vm = 2
internal.l7r.poll_time.x = 1
internal.l7r.short_session = 120

# internal.hkd.perl.anyevent.backend = EV

# this value should ba adjusted in accordance to
# internal.database.pool.connection.global_timeout
# and internal.hkd.agent.ticker.timeout
internal.hkd.cluster.node.timeout = 600

# if the ticker agent is not able to tick the database for the
# following time, it aborts the HKD
internal.hkd.agent.ticker.timeout = 450

internal.vm.port.x = 5000
internal.vm.port.vma = 3030
internal.vm.port.ssh = 22

internal.vm.monitor.redirect = 0
internal.vm.reserved_cpu = 1000

internal.nxagent.display = 100

internal.nxagent.timeout.initiating = 20
internal.nxagent.timeout.listening = 10
internal.nxagent.timeout.suspending = 20
internal.nxagent.timeout.stopping = 20

internal.vma.on_printing.connected = ${path.qvd.bin}/qvd-printing
internal.vma.on_printing.suspended = ${path.qvd.bin}/qvd-printing
internal.vma.on_printing.stopped = ${path.qvd.bin}/qvd-printing

internal.vma.printing.config = ${path.run}/printing.conf
internal.vma.slave.config = ${path.run}/slave.conf
internal.vma.nxagent.config = ${path.run}/nxagent.conf

# TODO: some of these DB settings may not be used anymore, cleanup them!
internal.database.client.connect.timeout = 20
internal.database.client.socket.keepidle = 20
internal.database.client.socket.keepintvl = 5
internal.database.client.socket.keepcnt = 4

internal.database.pool.connection.timeout = 10
internal.database.pool.connection.global_timeout = 400
internal.database.pool.size = 2
internal.database.pool.connection.delay = 10
internal.database.pool.connection.retries = 100

internal.hkd.stopping.l7rs.timeout = 300
internal.hkd.stopping.vms.timeout = 300
internal.hkd.killing.vms.retry.timeout = 100

internal.hkd.agent.ticker.delay = 120
internal.hkd.agent.command_handler.delay = 60
internal.hkd.agent.vm_command_handler.delay = 61
internal.hkd.agent.expiration_monitor.delay = 3600

internal.hkd.agent.cluster_monitor.delay = 120
internal.hkd.agent.cluster_monitor.long_delay = 600
internal.hkd.agent.cluster_monitor.fuzzy_delay = 30

internal.hkd.agent.rpc.retry.count = 3
internal.hkd.agent.rpc.retry.delay = 5
internal.hkd.agent.rpc.timeout = 3

internal.hkd.vmhandler.killer.delay = 10

internal.hkd.l7r.timeout.on_state.killing = 10

internal.hkd.lxc.timeout.on_state.starting.setup.delaying_untar.delaying = 60
internal.hkd.lxc.timeout.on_state.stopping.shutdown.waiting_for_lxc = 180
internal.hkd.lxc.timeout.on_state.stopping.stop.waiting_for_lxc = 120
internal.hkd.lxc.timeout.on_state.zombie.config.delaying = 60
internal.hkd.lxc.timeout.on_state.zombie.reap.waiting_for_lxc = 120
internal.hkd.lxc.timeout.on_state.zombie.reap.delaying = 60
internal.hkd.lxc.timeout.on_state.zombie.db.delaying = 60

internal.hkd.kvm.timeout.on_state.stopping.shutdown.waiting_for_kvm = 180
internal.hkd.kvm.timeout.on_state.stopping.stop.waiting_for_kvm = 180
internal.hkd.kvm.timeout.on_state.zombie.config.delaying = 60
internal.hkd.kvm.timeout.on_state.zombie.reap.waiting_for_kvm = 120
internal.hkd.kvm.timeout.on_state.zombie.reap.delaying = 60
internal.hkd.kvm.timeout.on_state.zombie.db.delaying = 60

internal.hkd.vmhandler.vma.failed.max_count.on.starting = 40
internal.hkd.vmhandler.vma.failed.max_count.on.running = 10

internal.hkd.vmhandler.vma.failed.max_time.on.starting = 180
internal.hkd.vmhandler.vma.failed.max_time.on.running = 320
internal.hkd.vmhandler.vma_monitor.delay.after.error = 10
internal.hkd.vmhandler.vma_monitor.delay.after.ok = 120
internal.hkd.lxc.does.not.cleanup = 0
internal.hkd.lxc.killer.retries = 10
internal.hkd.lxc.killer.destroy_lxc.timeout = 100
internal.hkd.lxc.killer.umount.timeout = 100
internal.hkd.lxc.acquire.untar.lock.delay = 2

internal.hkd.command.timeout.lxc-stop = 30
internal.hkd.agent.dhcpdhandler.delay = 2

internal.hkd.debugger.run = 0
internal.hkd.debugger.socket = /root/hkd-debug

internal.hkd.lock.path = ${path.run}/hkd.lock
internal.hkd.vm.lock.path = ${path.run}/hkd-vm.lock

internal.hkd.max_heavy = 10

internal.hkd.agent.l7rmonitor.delay = 60
internal.hkd.agent.l7rkiller.delay = 61

internal.hkd.agent.config.delay = 10

internal.hkd.nothing.timeout.on_state.starting = 5
internal.hkd.nothing.timeout.on_state.running = 5
internal.hkd.nothing.timeout.on_state.stopping = 5
internal.hkd.nothing.timeout.on_state.zombie = 100

internal.l7r.nothing.timeout.x_start = 5
internal.l7r.nothing.timeout.x_state = 5
internal.l7r.nothing.timeout.run_forwarder = 5

internal.untar-dis.lock.path = ${path.run}/untar-dis.lock

