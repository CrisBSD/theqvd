package QVD::Test::SingleServer;
use parent qw(QVD::Test);

use strict;
use warnings;

use Test::More qw(no_plan);

BEGIN {
    $QVD::Config::USE_DB = 0;
}

use QVD::Config;
use QVD::DB::Simple;

my $node;

sub check_environment : Test(startup => 6) {
    ok(-f '/etc/qvd/node.conf',		'Existence of QVD configuration, node.conf');
    ok(-f '/usr/bin/qvd-noded.pl',	'QVD node installation');

    my $bridge = cfg('vm.network.bridge');
    ok($bridge,				'Bridge definition in node.conf');
    ok(!system("ip addr show $bridge"), "Existence of VM network bridge $bridge");

    my $nodename = cfg('nodename');
    my $noders = rs(Host)->search({name => $nodename});
    ok($nodename,			'Node name definition in node.conf');
    is($noders->count, 1, 		"Presence of node $nodename in the database");

    $node = $noders->first;
}

sub zz_start_node : Test(startup) {
    my $nodert = $node->runtime;
    my $orig_ts = $nodert->ok_ts;
    my $start_timeout = 10;
    system('/usr/bin/qvd-noded.pl start');
    while ($nodert->ok_ts == $orig_ts) {
	sleep 1;
	$nodert->discard_changes;
	$start_timeout-- or fail("Node didn't start"), last;
    }
}

sub aa_stop_node : Test(shutdown) {
    system('/usr/bin/qvd-noded.pl stop');
}

sub block_node : Test() {
    # TODO check connect
    $node->runtime->block;
    # TODO check connect
    $node->runtime->unblock;
    # TODO check connect
}
