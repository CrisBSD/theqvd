#!/usr/bin/perl

use strict;
use warnings;

use App::Daemon qw/daemonize/;
use QVD::HKD;
use QVD::Config;

my $PID_FILE = QVD::Config->get('hkd_pid_file');

$App::Daemon::pidfile = $PID_FILE;
$App::Daemon::logfile = QVD::Config->get('hkd_log_file');

use Log::Log4perl qw(:levels);
$App::Daemon::loglevel = $DEBUG;
$App::Daemon::as_user = "root";

daemonize;
my $hkd = QVD::HKD->new(loop_wait_time => 5);
$hkd->run;


