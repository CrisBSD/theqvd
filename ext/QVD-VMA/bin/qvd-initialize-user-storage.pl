#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my $fstype;
my $mount_point;
my $user;

GetOptions('type|t=s' =>  \$fstype, 
	'user|u=s' => \$user,
	'mount-point=s' => \$mount_point);

$fstype //= 'ext3';
$mount_point //= '/home';
$user //= 'qvd';

unless (system ("mount", "/dev/sdb1", $mount_point) == 0) {
    die 'Unable to mount user storage' if -e '/dev/sdb1';

    system ('echo , | sfdisk /dev/sdb') == 0
	or die "Unable to create partition table on user storage";

    system ('mkfs.'.$fstype, '/dev/sdb1') == 0
	or die "Unable to create file system on user storage";

    system ('mount', '/dev/sdb1', $mount_point) == 0
	or die 'Unable to mount user storage';

    system ('cp', '-a', '/etc/skel', $mount_point.'/'.$user) == 0
	or die 'Unable to copy /etc/skel to user storage';

    system ('chown', '-R', $user, $mount_point.'/'.$user) == 0
	or die 'Unable to change the owner of user storage to '.$user;
}
