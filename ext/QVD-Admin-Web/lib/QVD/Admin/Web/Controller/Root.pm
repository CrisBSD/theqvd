package QVD::Admin::Web::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

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
    $c->go('login', @_) unless $c->user_exists;
    
    $c->stash->{data} = $c->model('QVD::Admin::Web');

}

sub propget :Local {
    my ( $self, $c ) = @_;
    # Should be a result of propget, and not implemented here
    # TODO
    my $admin = $c->model('QVD::Admin::Web')->admin;
    $admin->reset_filter();
    my $rs = $admin->get_resultset('user');
    my @props = $rs->search_related('properties', {});
    my @var = map { { login => $_->user->login, key => $_->key, value => $_->value } } @props;
    $c->stash->{propgetvar} = \@var;
    $c->stash->{update_uri} = $c->uri_for('/_update_propget');
}


sub _update_propget : Local {
    my ($self, $c) = @_;
 
    $c->model('QVD::Admin::Web')
      ->find({ login => $c->req->params->{login} })
      ->update({
        $c->req->params->{field} => $c->req->params->{value}
      });
 
    $c->res->body( $c->req->params->{value} );
}


sub propset :Local {
    my ( $self, $c ) = @_;
}

sub propsetButton :Local {
    my ( $self, $c ) = @_;
    # Should be a result of propget, and not implemented here
    # TODO
    my $admin = $c->model('QVD::Admin::Web')->admin;
    my $login = $c->req->body_params->{login}; # only for a POST request
    my $key = $c->req->body_params->{key};
    my $value = $c->req->body_params->{value}; 
    $admin->set_filter("login=$login");
    $admin->{current_object} = 'user';
    $admin->cmd_user_propset("$key=$value");
    $admin->reset_filter();
}


sub index :Path :Args(0) {
    my ( $self, $c ) = @_;   
    $c->go('login', @_) unless $c->user_exists;

    
    my $model = $c->model('QVD::Admin::Web');
    
    my $rs = $model->vm_stats("");
    $c->stash('vm_stats_fields' => join ('|', map {$_->vm_state." (".$_->get_column('vm_count').")"} @$rs));
    $c->stash('vm_stats_values' => join (',', map {$_->get_column('vm_count')} @$rs));
    
    $rs = $model->host_stats("");
    $c->stash('host_stats_fields' => join ('|', map {$_->get_column('host_state')." (".$_->get_column('host_count').")"} @$rs));
    $c->stash('host_stats_values' => join (',', map {$_->get_column('host_count')} @$rs));
    
    $rs = $model->user_total_stats("");
    $c->stash('user_total_stats' => $rs);
    
    $rs = $model->vm_total_stats("");
    $c->stash('vm_total_stats' => $rs);
    
    $rs = $model->host_total_stats("");
    $c->stash('host_total_stats' => $rs);
    
    $rs = $model->osi_total_stats("");
    $c->stash('osi_total_stats' => $rs);
    
    $rs = $model->session_connected_stats();
    $c->stash('session_connected_stats' => $rs);


}

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

sub login :Local {
    my ( $self, $c ) = @_;
    
    if (    my $user     = $c->req->param("log")
        and my $password = $c->req->param("pwd") )
    {
        if ( $c->authenticate( { username => $user,
                                 password => $password } ) ) {
            $c->res->redirect('/');
        } else {
            $c->stash->{current_view}='TTMin';
            # login incorrect
        }
    }
    else {
        $c->stash->{current_view}='TTMin';
        # invalid form input
    }
}

sub logout :Local {
    my ( $self, $c ) = @_;
    
    $c->logout;
    
    $c->go('login', @_);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Nito Martinez,,,

=head1 COPYRIGHT

Copyright 2009-2010 by Qindel Formacion y Servicios S.L.

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU GPL version 3 as published by the Free
Software Foundation.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;
1;
