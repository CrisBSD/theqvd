package QVD::Admin::Web::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

QVD::Admin::Web::Controller::Root - Root Controller for QVD::Admin::Web

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 index

=cut

sub about :Local {
    my ( $self, $c ) = @_;
    # Hello World
    $c->stash->{data} = $c->model('QVD::Admin::Web');

}

sub propget :Local {
    my ( $self, $c ) = @_;

    my $db = $c->model('QVD::Admin::Web')->db;
    my $rs = $db->resultset('User');
    my @props = $rs->search_related('properties', {});
    my @var = map { { login => $_->user->login, key => $_->key, value => $_->value } } @props;

    $c->stash->{propgetvar} = \@var;
}

sub propset :Local {
    my ( $self, $c ) = @_;
}

sub propsetButton :Local {
    my ( $self, $c ) = @_;

    my $admin = $c->model('QVD::Admin::Web')->admin;
    my $login = $c->req->body_params->{login}; # only for a POST request
    my $key = $c->req->body_params->{key};
    my $value = $c->req->body_params->{value}; 
    $admin->set_filter("login=$login");
    $admin->{current_object} = 'user';
    $admin->cmd_user_propset("$key=$value");
}


sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

}

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Nito Martinez,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
