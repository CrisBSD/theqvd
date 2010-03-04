#!/usr/bin/perl

use strict;
use warnings;

use App::Daemon qw/daemonize/;
use QVD::VMA;
use QVD::VMA::Config;

my $rundir = cfg('vma.run_dir', '/var/run/qvd');
-d $rundir or mkdir $rundir;
$App::Daemon::pidfile = cfg('vma.pid_file', '/var/run/qvd/vma.pid');
$App::Daemon::logfile = cfg('vma.log_file', '/var/log/qvd/vma.log');
$App::Daemon::as_user = 'root';

use Log::Log4perl qw(:levels);
Log::Log4perl::init('log4perl.conf');

daemonize();
my $vma = QVD::VMA->new(port => 3030);
$vma->run();
