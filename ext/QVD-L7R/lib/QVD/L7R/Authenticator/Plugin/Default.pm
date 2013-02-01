package QVD::L7R::Authenticator::Plugin::Default;

use strict;
use warnings;

use QVD::DB::Simple;
use QVD::Log;

use parent 'QVD::L7R::Authenticator::Plugin';

sub authenticate_basic {
    my ($plugin, $auth, $login, $passwd, $l7r) = @_;
    DEBUG "authenticating $login";

    # Reject passwordless login #1209
    return () if $passwd eq '';

    my $rs = rs(User)->search({login => $login, password => $passwd});
    return () unless $rs->count > 0;
    DEBUG "authenticated ok";
    1;
}

1;
