package QVD::Config;

use warnings;
use strict;

use Config::Tiny;

my $config = Config::Tiny->read('config.ini');

=head1 NAME

QVD::Config - The great new QVD::Config!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

This module encapsulate configuration parameteres access.

    use QVD::Config;

    my $foo = QVD::Config->get('field');
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head2 QVD::Config->get($key)

Returns the configuration associated to the given key

=cut

my %cache;
my $cached;

sub get {
    my ($class, $key) = @_;
    unless ($cached) {
	my $db = QVD::DB->new();
	%cache = map { $_->key => $_->value} $db->resultset('Config')->all;
	$db->txn_commit;
	$cached = 1;
    }
    $cache{$key};
}

=head1 AUTHOR

Hugo Cornejo, C<< <hcornejo at qindel.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-qvd-config at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=QVD-Config>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc QVD::Config


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=QVD-Config>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/QVD-Config>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/QVD-Config>

=item * Search CPAN

L<http://search.cpan.org/dist/QVD-Config/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Hugo Cornejo.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of QVD::Config
