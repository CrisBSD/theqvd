package QVD::DB;

our $VERSION = '0.01';

use warnings;
use strict;

use Carp;
use DBIx::Class::Exception;
use Config::Tiny;

use parent qw(DBIx::Class::Schema);

__PACKAGE__->load_namespaces(result_namespace => 'Result');
__PACKAGE__->exception_action(sub { croak @_ ; DBIx::Class::Exception::throw(@_);});

sub new {
    my $class = shift;
    my %params = @_;
    my $cdb = {};
    if (%params) {
	$cdb = \%params;
    } else {
	# Load database configuration from file
	my $config = Config::Tiny->read('/etc/qvd/config.ini');
	$cdb = $config->{database};
    }
    my $conn_data_source = $cdb->{data_source};
    my $conn_username = $cdb->{username};
    my $conn_password = $cdb->{password};
    $class->SUPER::connect($conn_data_source,
                           $conn_username, $conn_password,
                           { RaiseError => 1,
                             AutoCommit => 1,
                             quote_char => '"',
                             name_sep   => '.',
                             pg_enable_utf8 => 1 });
}

sub deploy {
    my $db = shift;
    $db->SUPER::deploy(@_);

    my %initial_values = ( VM_State   => [qw(stopped starting running
                                             stopping_1 stopping_2
                                             zombie_1 zombie_2)],
                           VM_Cmd     => [qw(start stop)],
                           User_State => [qw(disconnected connecting
                                             connected aborting)],
                           User_Cmd   => [qw(abort)] );

    while (my ($rs, $values) = each %initial_values) {
	foreach my $name (@$values) {
	    $db->resultset($rs)->create({name => $name});
	}
    }
}

sub erase {
    my $db = shift;
    my $dbh = $db->storage->dbh;
    for my $table (qw( vm_runtimes
		       vms
		       vm_properties
		       osis
		       host_runtimes
		       hosts
		       host_properties
		       users
		       user_extras
		       user_properties
		       vm_states
		       user_states
		       vm_cmds
		       user_cmds
		       configs
		       ssl_configs )
		  ) {

	eval {
	    warn "DROPPING $table\n";
	    $dbh->do("DROP TABLE $table CASCADE");
	};
	warn "Error (DROP $table): $@" if $@;
    }
}

1;

__END__

=head1 NAME

QVD::DB - ORM for QVD entities

=head1 SYNOPSIS

    use QVD::DB;

    my $foo = QVD::DB->new();
    ...

=head1 DESCRIPTION

=head2 API

=over 4

=item $db = QVD::DB->new([data_source => $source, username => $user, password => $pw])

Opens a new connection to the database. Uses configuration from the file
F<config.ini> if the data source, username and password are not given.

=item $db->deploy() 

Creates the tables needed for QVD.

=item $db->erase()

Drops all the database tables.

=back

=head1 AUTHORS

Joni Salonen (jsalonen at qindel.es)

Nicolas Arenas (narenas at qindel.es)

Salvador FandiE<ntilde>o (sfandino@yahoo.com)

=head1 BUGS

Please report any bugs or feature requests to C<bug-qvd-db at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=QVD-DB>.  I will be
notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2009, 2010 Qindel Formacion y Servicios S.L., all rights
reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
