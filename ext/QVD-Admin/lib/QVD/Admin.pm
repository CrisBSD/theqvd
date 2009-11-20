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
    my $db_object;
    
    if (defined $obj) {
	$db_object = $self->{objects}{$obj};
	if (!defined $db_object) {
	    $self->die_and_help ("$obj: Unsupported object", $obj);
	}
    } else {
	$self->die_and_help ("Void object", $obj);
    }
    if ($self->{filter}) {
    	$self->{db}->resultset($db_object)->search($self->{filter});
    } else {
    	$self->{db}->resultset($db_object);
    }
}

sub dispatch_command {
    my ($self, $object, $command, $help, @args) = @_;
    my $rs = $self->_get_result_set($object);
    $self->die_and_help ("$object: Valid command expected", $object) unless defined $command;
    my $method = $self->can($help ? "help_${object}_${command}" : "cmd_${object}_${command}");
    if (defined $method) {
	$self->$method($rs, @args);
    } else {
	$self->die_and_help ("$object: $command not implemented", $object);
    }
}

sub _format_timespan {
    my $seconds = shift;
    my $secs = $seconds%60;
    my $mins = ($seconds /= 60) % 60;
    my $hours = ($seconds /= 60);
    return sprintf "%02d:%02d:%02d", $hours, $mins, $secs;
}

sub _print_header {
    my @titles = @_;
    print join("\t", @titles)."\n";
    print join("\t", map { s/./-/g; $_ } @titles)."\n";
}

sub cmd_host_list {
    my ($self, $rs, @args) = @_;
    _print_header "Id", "Name", "Address ","HKD", "VMs assigned"
	    unless $self->{quiet};

    while (my $host = $rs->next) {
	# FIXME proper formatting
	my $hkd_ts = defined $host->runtime ? $host->runtime->hkd_ok_ts : undef;
	my $mins = defined $hkd_ts ? _format_timespan(time - $hkd_ts) : '-';
	print join "\t", $host->id, $host->name, $host->address, $mins,
			    $host->vms->count;
	print "\n";

    }
}

sub help_host_list {
    print <<EOT
host list: Returns a list with the virtual machines.
usage: host list
    
  Lists consists of Id, Name, Address, HKD and VMs assigned, separated by tabs.
    
Valid options:
    -f [--filter] FILTER : list only host matched by FILTER
    -q [--quiet]         : don't print the header
EOT
}

sub cmd_user_list {
    my ($self, $rs, @args) = @_;
    _print_header "Id","Login" unless $self->{quiet};
    while (my $user = $rs->next) {
	printf "%s\t%s\n", $user->id, $user->login;
    }
}

sub help_user_list {
    print <<EOT
user list: Returns a list with the users.
usage: user list
    
  Lists consists of Id and Login, separated by tabs.
    
Valid options:
    -f [--filter] FILTER : list only user matched by FILTER
    -q [--quiet]         : don't print the header
EOT
}

sub cmd_vm_list {
    my ($self, $rs, @args) = @_;
    _print_header "Id","Name","State","Host" unless $self->{quiet};
    while (my $vm = $rs->next) {
	my $vm_runtime = $vm->vm_runtime;
	my $host = $vm_runtime->host;
	my $host_name = defined $host ? $host->name : '-';
	print join "\t", $vm->id, $vm->name, $vm_runtime->vm_state, $host_name;
	print "\n";
    }
}

sub help_vm_list {
    print <<EOT
vm list: Returns a list with the virtual machines.
usage: vm list
    
  Lists consists of Id, Name, State and Host, separated by tabs.
    
Valid options:
    -f [--filter] FILTER : list only vm matched by FILTER
    -q [--quiet]         : don't print the header
EOT
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
    my ($self, $required_params, $rs, @args) = @_;
    my $params = ref $args[0] ? $args[0] : _split_on_equals @args;
    die "Invalid parameters" 
    	unless _set_equals([keys %$params], $required_params);
    $rs->create($params);
}

sub cmd_host_add {
    my $self = shift;
    my $row = $self->_obj_add([qw/name address/], @_);
    $self->{db}->resultset('Host_Runtime')
			    ->create({host_id => $row->id});
    print "Host added with id ".$row->id."\n" unless $self->{quiet};
}

sub cmd_vm_add {
    my ($self,$rs,@args) = @_;
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
				$rs, $params);
    $self->{db}->resultset('VM_Runtime')->create({
	    vm_id => $row->id,
	    vm_state => 'stopped',
	    x_state => 'disconnected',
	    user_state => 'disconnected',
	});
    print "VM added with id ".$row->id."\n" unless $self->{quiet};
}

sub cmd_user_add {
    my $self = shift;
    my $row = $self->_obj_add([qw/login password/], @_);
    print "User added with id ".$row->id."\n" unless $self->{quiet};
}

sub cmd_osi_add {
    my ($self, $rs, @args) = @_;
    my $params = _split_on_equals @args;

    # Default OSI parameters
    # FIXME Detect type of image and set use_overlay accordingly, iso=no overlay
    $params->{memory} //= 256;
    $params->{use_overlay} //= 1;
    
    use File::Basename qw/basename/;
    my $img = $params->{disk_image};
    $params->{disk_image} = basename($img);

    die "Invalid parameters" unless _set_equals([keys %$params],
	[qw/name memory use_overlay disk_image/]);

    # Copy image to ro-directory
    # FIXME Overwriting existing image should be an error
    die "disk_image is not optional" unless defined $params->{disk_image};
    my $destination = QVD::Config->get('ro_storage_path');
    use File::Copy qw/copy/;
    copy($img, $destination) or die "Unable to copy $img to storage: $^E";

    my $row = $rs->create($params);

    print "OSI added with id ".$row->id."\n" unless $self->{quiet};
}

sub _obj_del {
    my ($self, $obj, $rs) = @_;
    unless ($self->{quiet}) {
	if (scalar %{$self->{filter}} eq 0) {
	    print "Are you sure you want to delete all ${obj}s? [y/N] ";
	    my $answer = <>;
	    exit 0 unless $answer =~ /^y/i;
	}
    }
    print "Deleting ".$rs->count." ${obj}(s)\n" unless $self->{quiet};
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
    my ($self, $rs, @args) = @_;
    $self->_obj_del('OSI', $rs);
    # FIXME Should we delete the actual image file?
}

sub _obj_propset {
    my ($self, $rs, @args) = @_;
    my $params = _split_on_equals @args;
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

sub help_host_propset {
    print <<EOT
host propset: Sets host property.
usage: host propset [key=value...]
      
  Example:
  host propset weight=50kg maxtemp=56º
      
Valid options:
    -f [--filter] FILTER : sets host property to hosts matched by FILTER
EOT
}

sub cmd_user_propset {
    shift->_obj_propset(@_);
}

sub help_user_propset {
    print <<EOT
user propset: Sets user property.
usage: user propset [key=value...]
      
  Example:
  user propset genre=male timezone=+1
      
Valid options:
    -f [--filter] FILTER : sets host property to hosts matched by FILTER
EOT
}

sub cmd_vm_propset {
    shift->_obj_propset(@_);
}

sub help_vm_propset {
    print <<EOT
vm propset: Sets vm property.
usage: vm propset [key=value...]
      
  Example:
  vm propset usage=accounting priority=critical
      
Valid options:
    -f [--filter] FILTER : sets host property to hosts matched by FILTER
EOT
}

sub _obj_propget {
    my ($self, $display_cb, $rs, @args) = @_;
    my $condition = scalar @args > 0 ? {key => [@args]} : {};
    my @props = $rs->search_related('properties', $condition);
    print map { &$display_cb($_)."\t".$_->key.'='.$_->value."\n" } @props;
}

sub cmd_host_propget {
    shift->_obj_propget(sub { $_->host->name }, @_);
}

sub help_host_propget {
    print <<EOT
host propget: Gets host property.
usage: host propget [key...]
      
  Example:
  host propget usage priority
      
Valid options:
    -f [--filter] FILTER : sets host property to hosts matched by FILTER
EOT
}

sub cmd_user_propget {
    shift->_obj_propget(sub { $_->user->login }, @_);
}

sub help_user_propget {
    print <<EOT
user propget: Gets user property.
usage: host propget [key...]
      
  Example:
  host propget genre timezone
      
Valid options:
    -f [--filter] FILTER : sets host property to hosts matched by FILTER
EOT
}

sub cmd_vm_propget {
    shift->_obj_propget(sub { $_->vm->name }, @_);
}

sub help_vm_propget {
    print <<EOT
vm propget: Gets vm property.
usage: vm propget [key...]
      
  Example:
  vm propget usage priority
      
Valid options:
    -f [--filter] FILTER : sets host property to hosts matched by FILTER
EOT
}

sub cmd_config_set {
    my ($self, $rs, @args) = @_;
    my $params = _split_on_equals @args;
    foreach my $key (keys %$params) {
	$rs->update_or_create({
		key => $key,
		value => $params->{$key}
	    });
    }
}

sub cmd_config_get {
    my ($self, $rs, @args) = @_;
    my $condition = scalar @args > 0 ? {key => [@args]} : {};
    my @configs = $rs->search($condition);
    print map { $_->key.'='.$_->value."\n" } @configs;
}

sub cmd_vm_start {
    my ($self, $rs, @args) = @_;
    use QVD::VMAS;
    my $vmas = QVD::VMAS->new($self->{db});
    while (my $vm = $rs->next) {
	my $vm_runtime = $vm->vm_runtime;
	if ($vm_runtime->vm_state eq 'stopped') {
	    unless ($vmas->assign_host_for_vm($vm_runtime)) {
		print "Unable to assign VM ".$vm->id." to a host\n";
		next;
	    }
	    unless ($vmas->schedule_start_vm($vm_runtime)) {
		print "Unable to start VM ".$vm->id." on host "
			.$vm_runtime->host->name."\n";
		next;
	    }
	    print "Scheduled the start of VM ".$vm->id." on host ".
		$vm_runtime->host->name."\n" unless $self->{quiet};
	} else {
	    print "VM ".$vm->id." is not in the 'stopped' state\n" unless $self->{quiet};
	}
    }
}

sub help_vm_start {
    print <<EOT
vm start: Starts virtual machine.
usage: vm start
      
Valid options:
    -f [--filter] FILTER : starts virtual machine matched by FILTER
    -q [--quiet]         : don't print the command message
EOT
}

sub cmd_vm_stop {
    my ($self, $rs, @args) = @_;
    use QVD::VMAS;
    my $vmas = QVD::VMAS->new($self->{db});
    while (my $vm = $rs->next) {
	my $vm_runtime = $vm->vm_runtime;
	if ($vm_runtime->vm_state eq 'running') {
	    $vmas->schedule_stop_vm($vm_runtime);
	    print "Scheduled the stop of VM ".$vm->id." on host ".
		$vm_runtime->host->name."\n" unless $self->{quiet};
	} else {
	    print "VM ".$vm->id." is not in the 'running' state\n"
		unless $self->{quiet};
	}
    }
}

sub help_vm_stop {
    print <<EOT
vm stop: Stops virtual machine.
usage: vm stop
      
Valid options:
    -f [--filter] FILTER : stops virtual machine matched by FILTER
    -q [--quiet]         : don't print the command message
EOT
}

sub cmd_vm_disconnect_user {
    my ($self, $rs, @args) = @_;
    use QVD::VMAS;
    my $vmas = QVD::VMAS->new($self->{db});
    while (my $vm = $rs->next) {
	my $vm_runtime = $vm->vm_runtime;
	if ($vm_runtime->user_state eq 'connected') {
	    print "Disconnecting user on VM ".$vm->id,"\n";
	    $vmas->disconnect_nx($vm_runtime);
	} else {
	    print "No user connected on VM ".$vm->id,"\n";
	}
    }
}

sub help_vm_disconnect_user{
    print <<EOT
vm disconnect_user: Disconnects user.
usage: vm disconnect_user
      
Valid options:
    -f [--filter] FILTER : disconnects user filter by FILTER
    -q [--quiet]         : don't print the command message
EOT
}

# FIXME Refactor to remove duplication between ssh and vnc connections
sub cmd_vm_ssh {
    my ($self, $rs, @args) = @_;
    if ($rs->count > 1) {
	die 'Filter matches more than one VM';
    }
    my $vm = $rs->single;
    die 'No matching VMs' unless defined $vm;
    my $vm_runtime = $vm->vm_runtime;
    die 'VM is not running' unless $vm_runtime->vm_state eq 'running';
    my $ssh_port = $vm_runtime->vm_ssh_port;
    die 'ssh access is disabled' unless defined $ssh_port;
    my @cmd = (ssh => ($vm_runtime->vm_address, -p => $ssh_port, @args));
    exec @cmd;
}

sub help_vm_ssh {
    print <<EOT
vm ssh: Connects to the virtual machine SSH server.
usage: vm ssh

  To pass aditional parameters to SSH add them to the command line after --
  
  Example:
  vm ssh -- -l qvd
       
Valid options:
    -f [--filter] FILTER : connect to the virtual machine matched by FILTER
    -q [--quiet]         : don't print the header
EOT
}

sub cmd_vm_vnc {
    my ($self, $rs, @args) = @_;
    if ($rs->count > 1) {
	die 'Filter matches more than one VM';
    }
    my $vm = $rs->single;
    die 'No matching VMs' unless defined $vm;
    my $vm_runtime = $vm->vm_runtime;
    die 'VM is not running' unless $vm_runtime->vm_state eq 'running';
    my $vnc_port = $vm_runtime->vm_vnc_port;
    die 'vnc access is disabled' unless defined $vnc_port;
    my @cmd = (vncviewer => ($vm_runtime->vm_address.'::'.$vnc_port, @args));
    exec @cmd;
}

sub help_vm_vnc {
    print <<EOT
vm ssh: Connects to the virtual machine VNC server.
usage: vm vnc

  To pass aditional parameters to VNC add them to the command line after --
  
  Example:
  vm vnc -- --depth 8
       
Valid options:
    -f [--filter] FILTER : connect to the virtual machine matched by FILTER
    -q [--quiet]         : don't print the header
EOT
}

sub die_and_help {
    my ($self, $message, $obj) = @_;
    
    $message = "Unknown error" unless defined($message);
    
    my @funcs = do {
	no strict;
	grep exists &{"QVD::Admin::$_"}, keys %{"QVD::Admin::"};
    };
    
    @funcs = grep {s/^cmd_//} @funcs;
    @funcs = grep {m/^${obj}_/} @funcs if exists $self->{objects}{$obj};
    @funcs = grep {s/_/ /} @funcs;

    
    print $message.", available subcommands:\n   ";
    
    print join "\n   ", sort @funcs;
    print "\n\n";
    
    
    
    
    exit;
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
