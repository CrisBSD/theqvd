#!/usr/lib/qvd/bin/perl

use strict;
use warnings;

my ($pid, $delay) = @ARGV;

$pid or die <<EOU;
Usage:
  $0 pid [delay]

EOU

$delay ||= 10;

open STDERR, '>&STDOUT';

sub run_cmd {
    my $cmd = shift;
    print "++++++++ $cmd ++++++++\n";
    system $cmd;
}

while (1) {
    print "=============================================================";
    kill USR1 => $pid;
    run_cmd 'date';
    run_cmd 'iostat';
    run_cmd 'vmstat';
    run_cmd 'top -bn1';
    run_cmd 'iotop -bn1';
    run_cmd 'cat /tmp/hkd-vm-states';
    sleep 10;
}
