package QVD::Admin::Web::Controller::Hosts;

use strict;
use warnings;
use parent 'Catalyst::Controller::FormBuilder';
use Data::FormValidator::Constraints qw(:closures);
use Data::Dumper;

__PACKAGE__->config(
    'Controller::FormBuilder' => {
        new => {
            method     => 'post',
            stylesheet => 1,
            #messages   => '/locale/fr_FR/form_messages.txt',
			messages => ':es_ES'
        },
        #template_type => 'HTML::Template',
        #source_type   => 'CGI::FormBuilder::Source::File',
    }
);


=head1 NAME

QVD::Admin::Web::Controller::Hosts - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    $c->go('list');
}

sub view : Local :Args(1){
	my ( $self, $c, $id) = @_;
	my $model = $c->model('QVD::Admin::Web');
	my $host = $model->host_find($id );
	$c->stash(host => $host);
}

sub list : Local {
    my ( $self, $c ) = @_;
    my $model = $c->model('QVD::Admin::Web');
    my $rs    = $model->host_list("");
    $c->stash->{host_list} = $rs;
}

sub add : Local Form {
    my ( $self, $c ) = @_;
    my $form  = $self->formbuilder;

    my $model = $c->model('QVD::Admin::Web');
	if ( $form->submitted ) {
        if ( $form->validate ) {
            my $name = $form->field('name');
            my $address  = $form->field('address');
            if ( my $id = $model->host_add( $name, $address ) ) {
                $c->flash->{response_type} = "success";
                $c->flash->{response_msg} = "$name añadido correctamente con id $id";
            }
            else {
                # FIXME response_type must be an enumerated
                $c->flash->{response_type} = "error";
                $c->flash->{response_msg}  = $model->error_msg;
            }
            $c->response->redirect( $c->uri_for( $self->action_for('list') ) );
        }
        else {
            $c->stash->{ERROR} = "INVALID FORM";
            $c->stash->{invalid_fields} = [ grep { !$_->validate } $form->fields ];
        }
    }
}

sub del_submit : Local {
    my ( $self, $c ) = @_;
    my $model = $c->model('QVD::Admin::Web');

    my $result = $c->form(
        required           => ['id'],
        constraint_methods => { 'id' => qr/^\d+$/, }
    );

    if ( !$result->success ) {
        $c->flash->{response_type} = "error";
        $c->flash->{response_msg} =
          "Error in parameters: " . $model->build_form_error_msg($result);
    }
    else {
        my $id = $c->req->body_params->{id};    # only for a POST request
        if ( my $countdel = $model->host_del($id) ) {
            $c->flash->{response_type} = "success";
            $c->flash->{response_msg}  = "$id eliminado correctamente";
        }
        else {

            # FIXME response_type must be an enumerated
            $c->flash->{response_type} = "error";
            $c->flash->{response_msg}  = $model->error_msg;
        }
    }

    #$c->forward('list');
    $c->response->redirect( $c->uri_for( $self->action_for('list') ) );
}


#sub add_submit_json :Local {
#    $c->stash->{current_view} = 'JSON';
#    $c->view('JSON')->{expose_stash} = [ qw(id) ];
#    my $hostname = $c->req->body_params->{hostname}; # only for a POST request
#    my $mac = $c->req->body_params->{mac}; # only for a POST request
#    my $console = $c->req->body_params->{console}; # only for a POST request
#    $c->stash
#        (
#         id => $id,
#        );
#}

=head1 AUTHOR

QVD,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


1;
