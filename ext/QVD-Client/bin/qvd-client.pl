#!/usr/lib/qvd/bin/perl 

eval 'exec /usr/lib/qvd/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

{
    package QVD::Client::App;

    use warnings;
    use strict;
    use QVD::Config::Core qw(core_cfg);

    our $WINDOWS = ($^O eq 'MSWin32');

    our $user_dir = File::Spec->rel2abs($WINDOWS
        ? File::Spec->join($ENV{APPDATA}, 'QVD')
        : File::Spec->join((getpwuid $>)[7] // $ENV{HOME}, '.qvd'));
    mkdir $user_dir;

    our $app_dir = core_cfg('path.client.installation', 0);
    if (!$app_dir) {
        my $bin_dir = File::Spec->join((File::Spec->splitpath(File::Spec->rel2abs($0)))[0, 1]);
        my @dirs = File::Spec->splitdir($bin_dir);
        $app_dir = File::Spec->catdir( @dirs[0..$#dirs-1] ); 
    }

    our $user_certs_dir = File::Spec->rel2abs(core_cfg('path.ssl.ca.personal'), $user_dir);
}

use strict;
use warnings;

use Proc::Background; 
use JSON;

BEGIN {
    $QVD::Config::USE_DB = 0;
    @QVD::Config::Core::FILES = (
        '/etc/qvd/client.conf',
        ($ENV{HOME} || $ENV{APPDATA}).'/.qvd/client.conf',
        'qvd-client.conf',
    );

    # FIXME NX_CLIENT is used for showing the user information on things
    # like broken connection, perhaps we should show them to the user
    # instead of ignoring them? 
    $ENV{NX_CLIENT} = '/bin/false';
}

use QVD::Config::Core;
use QVD::Client::Proxy;

my $username = shift @ARGV;
my $password = shift @ARGV;
my $host = shift @ARGV;
my $port = shift @ARGV // core_cfg('client.host.port');
my $file = shift;
my $nonblocking=1;

# FIXME: do not use a heuristic but some command line flag for that
my $ssl = ($port =~ /43$/ ? 1 : undef);

my %connect_info = (
    link          => core_cfg('client.link'),
    slave         => core_cfg('client.slave.enable'),
    audio         => core_cfg('client.audio.enable'),
    printing      => core_cfg('client.printing.enable'),
    geometry      => core_cfg('client.geometry'),
    fullscreen    => core_cfg('client.fullscreen'),
    keyboard      => 'pc105/es',
    port          => $port,
    ssl           => $ssl,
    host          => $host,
    username      => $username,
    password      => $password,
    file          => $file,
);

my $delegate = QVD::Client::CLI->new(file => $file);
if ($file) {
    QVD::Client::Proxy->new($delegate, %connect_info)->open_file($file);
} else {
    QVD::Client::Proxy->new($delegate, %connect_info)->connect_to_vm();
}

package QVD::Client::CLI;

use Data::Dumper;
use QVD::Client::SlaveClient;
use QVD::Log;

sub new {
    my $class = shift;
    my %attrs = @_;
    bless \%attrs, $class;
}

sub proxy_set_environment {
    my ($self, %args) = @_;
    @ENV{keys %args} = values %args;
}

sub proxy_unknown_cert {
    my ($self, $cert_arr) = @_;
    my ($cert_pem_str, $cert_data) = @$cert_arr;
    print "$cert_data\n";
    print "Accept certificate? [y/N] ";
    return <STDIN> =~ /^y/i;
}

sub proxy_list_of_vm_loaded {
    my ($self, $vm_data) = @_;
    #my $vm;
    #if (@$vm_data > 0) {
    #    print "You have ".@$vm_data." virtual machines.\n";
    #    $vm = $vm_data->[rand @$vm_data];
    #    print "Connecting to the one called ".$vm->{name}."\n";
    #}
    #return $vm->{id};
    return 1;
}

sub proxy_connection_status {
    my ($self, $status) = @_;
    print "Connection status $status\n";
    if ($status eq 'FORWARDING') {
        $self->open_file($self->{file});
    }
}

sub proxy_connection_error {
    my $self = shift;
    my %args = @_;
    print 'Connection error: ',$args{message},"\n";
}

sub open_file {
    my ($self, $file) = @_;
    my $pid = fork;
    if ($pid == 0) {
        my $share = '/';
        for (my $conn_attempt = 0; $conn_attempt < 10; $conn_attempt++) {
            INFO("Starting folder sharing for $share, attempt $conn_attempt");
            local $@;
            my $client = QVD::Client::SlaveClient->new('localhost:12040');
            eval { $client->handle_share($share) };
            if ($@) {
                if ($@ =~ 'Connection refused') {
                    sleep 1;
                    next;
                }
                ERROR($@);
            } else {
                INFO("Folder sharing started for $share");
                INFO("Opening $file");
                $client = QVD::Client::SlaveClient->new('localhost:12040');
                $client->handle_open($file);
            }
            last;
        }
        exit;
    } elsif ($pid > 0) {
        INFO("Folder sharing running with PID $pid");
    } else {
        ERROR("Unable to run folder sharing: $^E");
    }
}

__END__

=head1 NAME

qvd-client.pl

=head1 DESCRIPTION

Proof of concept command line client for QVD

=cut
