#!perl

use Test::More tests => 2;


if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}
my $user = 'lpi';
my $pass = 'lpi';
use_ok( 'QVD::L7R::Authenticator::Plugin::Ldap' );
my $authenticator = QVD::L7R::Authenticator;
my $ldap = QVD::L7R::Authenticator::Plugin::Ldap;
ok(!QVD::L7R::Authenticator::Plugin::Ldap->authenticate_basic($authenticator, $user, $pass, undef), "Authenticate duplicate lpi uid");
