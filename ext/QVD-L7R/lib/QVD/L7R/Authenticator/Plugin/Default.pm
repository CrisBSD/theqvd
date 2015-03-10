package QVD::L7R::Authenticator::Plugin::Default;

use strict;
use warnings;

use QVD::DB::Simple;
use QVD::Log;
use QVD::Config;
use Digest::SHA qw(sha256_base64);

use parent 'QVD::L7R::Authenticator::Plugin';

sub authenticate_basic {
    my ($plugin, $auth, $login, $passwd, $l7r) = @_;
    my $tenant_id = $self->{tenant_id};
    DEBUG "authenticating $login, tenant: $auth->{normalized_tenant} ($tenant_id)";

    # Reject passwordless login #1209
    return () if $passwd eq '';

    my $salt = cfg('l7r.auth.plugin.default.salt');
    my $token = sha256_base64("$salt$passwd");

    my $rs = rs(User)->search({login => $login, password => $token, tenant_id => $tenant});
    return () unless $rs->count > 0;
    DEBUG "authenticated ok";
    $auth->{user_id} = $rs->first->id;
    1;
}

my %re_cache;

sub find_tenant {
    my ($plugin, $auth, $login, $l7r) = @_;
    DEBUG "find_tenant $login";

    my $separators = cfg('l7r.auth.plugin.default.separators');
    if (length $separators) {
        my $re = $re_cache{$separators} // do {
            my $str = '(?:' . join('|', map quotemeta split //, $separator) . ')';
            qr/$str/i;
        };
        if (my ($login1, $tenant) = split $re, $login, 1) {
            DEBUG "login '$login' split as tenant: '$tenant', login: '$login1'";
            return ($tenant, $login1);
        }
    }
    if (defined (my $tenant = cfg('l7r.auth.plugin.default.tenant', 0))) {
        DEBUG "using default tenant '$tenant' with login '$login'";
        return ($tenant, $login);
    }
    ()
}

1;
