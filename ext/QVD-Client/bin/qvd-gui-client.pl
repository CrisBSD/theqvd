#!/usr/bin/perl

package QVD::Client::App;

use strict;
use warnings;
use 5.010;

use Cwd;
use File::Spec;
use Proc::Background;

our ($WINDOWS, $DARWIN, $user_dir, $app_dir, $user_config_filename, $user_certs_dir, $pixmaps_dir);

BEGIN {
    $WINDOWS = ($^O eq 'MSWin32');
    $DARWIN = ($^O eq 'darwin');

    $user_dir = File::Spec->rel2abs($WINDOWS
                                    ? File::Spec->join($ENV{APPDATA}, 'QVD')
                                    : File::Spec->join((getpwuid $>)[7] // $ENV{HOME}, '.qvd'));
    mkdir($user_dir);

    # FIXME NX_CLIENT is used for showing the user information on things
    # like broken connection, perhaps we should show them to the user
    # instead of ignoring them? 
    $ENV{NX_CLIENT} = $WINDOWS ? 'cmd.exe /c :' : 'false';

    $user_config_filename = File::Spec->join($user_dir, 'client.conf');

    no warnings;
    $QVD::Config::USE_DB = 0;
    @QVD::Config::Core::FILES = ( ($WINDOWS ? () : ('/etc/qvd/client.conf')),
                                  $user_config_filename );
}

use QVD::Config::Core qw(set_core_cfg core_cfg);

# change defaults for log configuration before loading it
BEGIN {
    for (@ARGV) {
        if (my ($k, $v) = /^\s*([\w\.]+)\s*[:=\s]\s*(.*?)\s*$/) {
            set_core_cfg($k, $v);
        }
    }

    set_core_cfg('client.log.filename', File::Spec->join($user_dir, 'qvd-client.log'))
        unless defined core_cfg('client.log.filename', 0);
    $QVD::Log::DAEMON_NAME = 'client';

    $app_dir = core_cfg('path.client.installation', 0);
    if (!$app_dir) {
        my $bin_dir = File::Spec->join((File::Spec->splitpath(File::Spec->rel2abs($0)))[0, 1]);
        my @dirs = File::Spec->splitdir($bin_dir);
        $app_dir = File::Spec->catdir( @dirs[0..$#dirs-1] ); 
    }

}

use QVD::Log;

DEBUG "user_dir: $user_dir";
DEBUG "app_dir: $app_dir";

$user_certs_dir = File::Spec->rel2abs(core_cfg('path.ssl.ca.personal'), $user_dir);
DEBUG "user_certs_dir: $user_certs_dir";

$pixmaps_dir = File::Spec->rel2abs(core_cfg('path.client.pixmaps'), $app_dir);
$pixmaps_dir = File::Spec->rel2abs(core_cfg('path.client.pixmaps.alt'), $app_dir) unless -d $pixmaps_dir;
DEBUG "pixmaps_dir: $pixmaps_dir";

#$SIG{__DIE__} = sub { ERROR "@_"; die (@_) };

use QVD::Client::Frame;
use parent 'Wx::App';

sub OnInit {
    my $self = shift;
    DEBUG("OnInit called");

    if ($WINDOWS or $DARWIN) {
        my @cmd;
        if ($WINDOWS) {
            $ENV{DISPLAY} //= '127.0.0.1:0';
            @cmd = ( File::Spec->rel2abs(core_cfg('command.windows.xming'), $app_dir),
                     '-multiwindow', '-notrayicon', '-nowinkill', '-clipboard', '+bs', '-wm',
                     '-logfile' => File::Spec->join($user_dir, "xserver.log") );
        }
        else { # DARWIN!
            $ENV{DISPLAY} //= ':0';
            @cmd = qw(open -a X11 --args true);
        }
        if ( Proc::Background->new(@cmd) ) {
            DEBUG("X server started");
        } else {
            ERROR("X server failed to start");
        }
    }

    DEBUG("Showing frame");
    my $frame = QVD::Client::Frame->new();
    $self->SetTopWindow($frame);
    $frame->Show();
    return 1;
};

package main;
use QVD::Log;

Wx::InitAllImageHandlers();
my $app = QVD::Client::App->new();

DEBUG("Starting main loop");
$app->MainLoop();
INFO("Exiting");

__END__

=head1 NAME

qvd-client - The QVD GUI Client

=head1 DESCRIPTION

B<qvd-client> is a graphic client that lets a user to connect to a virtual machine and take control of the remote desktop.

=head1 COPYRIGHT

Copyright 2009-2010 by Qindel Formacion y Servicios S.L.

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU GPL version 3 as published by the Free
Software Foundation.
