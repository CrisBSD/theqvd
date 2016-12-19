package QVD::API::Query;

use 5.010;
use strict;
use warnings;
use Moose;

our $VERSION = '0.01';

has 'filter',      is => 'rw', isa => 'Str';
has 'action',      is => 'rw', isa => 'Str';
has 'defaults',    is => 'ro', isa => 'HashRef', default => sub {{};};
has 'tenant',      is => 'ro', isa => 'ArrayRef', required => 1;
has 'request',     is => 'rw', isa => 'QVD::API::REST::Request', required => 1;


sub BUILD
{
    my $self = shift;

    die "Neither action nor filter specified" 
	unless ($self->action || $self->filter);

    $self->request->defaults($self->defaults); # Adding fefault values
                                               # from Query configuration
    my $role = $self->request->{tenant};

    for my $tenant (@{$self->tenant})
    {
	return 1 if ($tenant eq 'all' || $tenant eq $role); 
    }

    die "Forbidden action";
}

1;
