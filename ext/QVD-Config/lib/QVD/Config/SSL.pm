package QVD::Config::SSL;

our $VERSION = '0.01';

use warnings;
use strict;

use QVD::DB;

sub get {
    my ($class, $key) = @_;
    my $db = QVD::DB->new();
    my $slot = $db->resultset('SSL_Config')->search({ key => $key })->first;
    defined $slot ? $slot->value : undef;
}

1;
