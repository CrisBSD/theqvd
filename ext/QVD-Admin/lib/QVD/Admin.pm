package QVD::Admin;

use warnings;
use strict;

use QVD::DB;
use QVD::Config;

sub new {
    my $class = shift;
    my $quiet = shift;
    my $db = shift // QVD::DB->new();
    my $self = {db => $db,
		filter => {},
		quiet => $quiet,
		objects => {
		    host => 'Host',
		    vm => 'VM',
		    user => 'User',
		    config => 'Config',
		    osi => 'OSI',
		},
    };
    bless $self, $class;
}

sub _split_on_equals {
    my %r = map { my @a = split /=/, $_, 2; $a[0] => $a[1] } @_;
    \%r
}

sub set_filter {
    my ($self, $filter_string) = @_;
    # 'a=b,c=d' -> {'a' => 'b', 'c' => 'd}
    my $conditions = _split_on_equals split /,\s*/, $filter_string;
    while (my ($k, $v) = each %$conditions) {
	if ($v =~ /[*?]/) {
	    $v =~ s/([_%])/\\$1/g;
	    $v =~ tr/*?/%_/;
	    $self->{filter}{$k} = {like => $v};
	} else {
	    $self->{filter}{$k} = $v;
	}
    }
}

sub _get_result_set {
    my ($self, $obj) = @_;
    my $db_object = $self->{objects}{$obj};
    if (!defined $db_object) {
	$self->die_and_help ("$obj: Unsupported object", $obj);
    }
    my $method = $self->can("get_result_set_for_${obj}");
    if ($method) {
	$self->$method;
    }
    elsif ($self->{filter}) {
	$self->{db}->resultset($db_object)->search($self->{filter});
    } else {
	$self->{db}->resultset($db_object);
    }
}

sub _filter_obj {
    my ($self, $term_map) = @_;
    my $filter = $self->{filter};
    while (my ($src,$dst) = each %$term_map) {
	$filter->{$dst} = delete $filter->{$src} if exists $filter->{$src}
    }
    $filter
}

sub get_result_set_for_vm {
    my ($self, @args) = @_;
    my %term_map = (
	name => 'me.name',
	osi => 'osi.name',
	user => 'user.login',
	host => 'host.name',
	state => 'vm_runtime.vm_state',
    );
    my $filter = $self->_filter_obj(\%term_map);
    $self->{db}->resultset('VM')->search($filter, {
	    join => ['osi', 'user', { vm_runtime => 'host'}],
	});
}
sub _set_equals {
    my ($a, $b) = @_;
    return 0 if scalar @$a != scalar @$b;
    my @a = sort @$a;
    my @b = sort @$b;
    foreach my $i (0 .. @a-1) {
	return 0 if $a[$i] ne $b[$i];
    }
    return 1;
}

sub _obj_add {
    my ($self, $required_params, @args) = @_;
    my $params = ref $args[0] ? $args[0] : _split_on_equals @args;
    unless (_set_equals([keys %$params], $required_params)) {
	die "The required parameters are: ",
	    join(", ", @$required_params);
    }
    my $rs = $self->_get_result_set($self->{current_object});
    $rs->create($params);
}

sub cmd_host_add {
    my $self = shift;
    my $row = $self->_obj_add([qw/name address/], @_);
    $self->{db}->resultset('Host_Runtime')
			    ->create({host_id => $row->id});
    $row->id
}

sub cmd_vm_add {
    my ($self,@args) = @_;
    my $params = _split_on_equals @args;
    if (exists $params->{osi}) {
	my $key = $params->{osi};
	my $rs = $self->{db}->resultset('OSI')
				->search({name => $key});
	die "$key: No such OSI" if ($rs->count() < 1);
	$params->{osi_id} = $rs->single->id;
	delete $params->{osi};
    }
    if (exists $params->{user}) {
	my $key = $params->{user};
	my $rs = $self->{db}->resultset('User')
				->search({login => $key});
	die "$key: No such user" if ($rs->count() < 1);
	$params->{user_id} = $rs->single->id;
	delete $params->{user};
    }
    $params->{storage} = '';
    my $row = $self->_obj_add([qw/name user_id osi_id ip storage/], 
				$params);
    $self->{db}->resultset('VM_Runtime')->create({
	    vm_id => $row->id,
	    osi_actual_id => $row->osi_id,
	    vm_state => 'stopped',
	    x_state => 'disconnected',
	    user_state => 'disconnected',
	});

    $row->id
}

sub cmd_user_add {
    my $self = shift;
    my $row = $self->_obj_add([qw/login password/], @_);
    $row->id
}

sub cmd_osi_add {
    my ($self, @args) = @_;
    my $params = _split_on_equals @args;

    # Default OSI parameters
    # FIXME Detect type of image and set use_overlay accordingly, iso=no overlay
    $params->{memory} //= 256;
    $params->{use_overlay} //= 1;
    $params->{user_storage_size} //= undef;
    
    use File::Basename qw/basename/;
    my $img = $params->{disk_image};
    $params->{disk_image} = basename($img);

    die "Invalid parameters" unless _set_equals([keys %$params],
	[qw/name memory use_overlay user_storage_size disk_image/]);

    # Copy image to ro-directory
    # FIXME Overwriting existing image should be an error
    die "disk_image is not optional" unless defined $params->{disk_image};
    my $destination = QVD::Config->get('ro_storage_path');
    use File::Copy qw/copy/;
    copy($img, $destination) or die "Unable to copy $img to storage: $^E";

    my $rs = $self->_get_result_set($self->{current_object});
    my $row = $rs->create($params);

    $row->id;
}

sub _obj_del {
    my ($self, $obj) = @_;
    my $rs = $self->_get_result_set($self->{current_object});
    $rs->delete_all;
}

sub cmd_host_del {
    shift->_obj_del('host', @_);
}

sub cmd_user_del {
    shift->_obj_del('user', @_);
}

sub cmd_vm_del {
    shift->_obj_del('vm', @_);
}

sub cmd_osi_del {
    my ($self, @args) = @_;
    $self->_obj_del('OSI', @args);
    # FIXME Should we delete the actual image file?
}

sub _obj_propset {
    my ($self, @args) = @_;
    my $params = _split_on_equals @args;
    my $rs = $self->_get_result_set($self->{current_object});
    # In principle you should be able to avoid looping over the result set using
    # search_related but the PostgreSQL driver doesn't seem to let us
    while (my $obj = $rs->next) {
	foreach my $key (keys %$params) {
	    $obj->properties->search({key => $key})->update_or_create(
		{ key => $key, value => $params->{$key} },
		{ key => 'primary' }
	    );
	}
    }
}

sub cmd_host_propset {
    shift->_obj_propset(@_);
}

sub cmd_user_propset {
    shift->_obj_propset(@_);
}

sub cmd_vm_propset {
    shift->_obj_propset(@_);
}

sub _obj_propget {
    my ($self, @args) = @_;
    my $rs = $self->_get_result_set($self->{current_object});
    my $condition = scalar @args > 0 ? {key => [@args]} : {};
    my @props = $rs->search_related('properties', $condition);
    return \@props;
}

sub cmd_host_propget {
    shift->_obj_propget(sub { $_->host->name }, @_);
}

sub cmd_user_propget {
    shift->_obj_propget(sub { $_->user->login }, @_);
}

sub cmd_vm_propget {
    shift->_obj_propget(sub { $_->vm->name }, @_);
}

sub cmd_config_set {
    my ($self, @args) = @_;
    my $params = _split_on_equals @args;
    my $rs = $self->_get_result_set($self->{current_object});
    foreach my $key (keys %$params) {
	$rs->update_or_create({
		key => $key,
		value => $params->{$key}
	    });
    }
}

sub cmd_config_get {
    my ($self, @args) = @_;
    my $condition = scalar @args > 0 ? {key => [@args]} : {};
    my $rs = $self->_get_result_set($self->{current_object});
    my @configs = $rs->search($condition);
    return \@configs;
}

sub cmd_vm_start {
    my ($self, @args) = @_;
    my $rs = $self->_get_result_set($self->{current_object});
    my $counter = 0;
    use QVD::VMAS;
    my $vmas = QVD::VMAS->new($self->{db});
    while (my $vm = $rs->next) {
	my $vm_runtime = $vm->vm_runtime;
	if ($vm_runtime->vm_state eq 'stopped') {
	    next unless $vmas->assign_host_for_vm($vm_runtime);
	    next unless $vmas->schedule_start_vm($vm_runtime);
	    $counter++;
	}
    }
    $counter
}

sub cmd_vm_stop {
    my ($self, @args) = @_;
    my $rs = $self->_get_result_set($self->{current_object});
    my $counter = 0;
    use QVD::VMAS;
    my $vmas = QVD::VMAS->new($self->{db});
    while (my $vm = $rs->next) {
	my $vm_runtime = $vm->vm_runtime;
	if ($vm_runtime->vm_state eq 'running') {
	    $vmas->schedule_stop_vm($vm_runtime);
	    $counter++;
	}
    }
    $counter
}

sub cmd_vm_disconnect_user {
    my ($self, @args) = @_;
    my $rs = $self->_get_result_set($self->{current_object});
    use QVD::VMAS;
    my $vmas = QVD::VMAS->new($self->{db});
    my $counter = 0;
    while (my $vm = $rs->next) {
	my $vm_runtime = $vm->vm_runtime;
	if ($vm_runtime->user_state eq 'connected') {
	    $vmas->disconnect_nx($vm_runtime);
	    $counter++;
	}
    }
    $counter
}

sub _get_single_running_vm_runtime {
    my $self = shift;
    my $rs = $self->_get_result_set('vm');
    if ($rs->count > 1) {
	die 'Filter matches more than one VM';
    }
    my $vm = $rs->single;
    die 'No matching VMs' unless defined $vm;
    my $vm_runtime = $vm->vm_runtime;
    die 'The VM is not running' unless $vm_runtime->vm_state eq 'running';
    $vm_runtime
}

sub cmd_vm_ssh {
    my ($self, @args) = @_;
    my $vm_runtime = $self->_get_single_running_vm_runtime;
    my $ssh_port = $vm_runtime->vm_ssh_port;
    die 'SSH access is disabled' unless defined $ssh_port;
    my @cmd = (ssh => ($vm_runtime->vm_address, -p => $ssh_port, @args));
    exec @cmd;
}

sub cmd_vm_vnc {
    my ($self, @args) = @_;
    my $vm_runtime = $self->_get_single_running_vm_runtime;
    my $vnc_port = $vm_runtime->vm_vnc_port;
    die 'VNC access is disabled' unless defined $vnc_port;
    my @cmd = (vncviewer => ($vm_runtime->vm_address.'::'.$vnc_port, @args));
    exec @cmd;
}

1;

__END__

=head1 NAME

QVD::Admin - The great new QVD::Admin!

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use QVD::Admin;

    my $foo = QVD::Admin->new();
    ...

=head1 AUTHOR

Qindel Formacion y Servicios S.L., C<< <joni.salonen at qindel.es> >>


=head1 COPYRIGHT & LICENSE

Copyright 2009 Qindel Formacion y Servicios S.L., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
