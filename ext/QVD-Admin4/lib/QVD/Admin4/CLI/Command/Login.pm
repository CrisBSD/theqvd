package QVD::Admin4::CLI::Command::Login;
use base qw( QVD::Admin4::CLI::Command );
use strict;
use warnings;





sub usage_text { 
"======================================================================================================
                                             LOGIN COMMAND USAGE
======================================================================================================

  login (Starts the Log In form. It will ask you a QVD administrator name, and a  password (and a 
         tenant in multitenant mode))

"
}






sub run
{
    my ($self, $opts, @args) = @_;

    my $app = $self->get_app;
    my $ua  = $app->cache->get('user_agent');
    my $url  = $app->cache->get('api_info_url');

    my $multitenant = eval {
        $ua->get("$url")->res->json('/multitenant')
    };

    my $login = $self->_read('Name');
    my $tenant = $multitenant ? $self->_read('Tenant') : undef;
    my $password = $self->read_password;

    $app->cache->set( login => $login );
    $app->cache->set( tenant_name => $tenant );
    $app->cache->set( password => $password );
    $app->cache->set( sid => undef );

    my $res = $self->ask_api(
        { action => 'current_admin_setup'});

    my $sid = $res->json('/sid');
    my $admin_id = $res->json('/admin_id');
    my $tenant_id = $res->json('/tenant_id');

    $app->cache->set( sid => $sid );
    $app->cache->set( admin_id => $admin_id );
    $app->cache->set( tenant_id => $tenant_id );
}

1;
