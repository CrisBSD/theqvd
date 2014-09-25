package QVD::Admin4;

use 5.010;
use strict;
use warnings;
use Moose;
use QVD::DB;
use QVD::DB::Simple;
use QVD::Config;
use File::Copy qw(copy move);
use Config::Properties;
use QVD::Admin4::Exception;
use DateTime;
use List::Util qw(sum);
our $VERSION = '0.01';

my $DB;

#########################
## STARTING THE OBJECT ##
#########################

sub BUILD
{
    my $self = shift;

    $DB = QVD::DB->new() // 
	QVD::Admin4::Exception->throw(code=>'2');
}

sub _db { $DB; }

#####################
### GENERIC FUNCTIONS
#####################

sub select
{
    my ($self,$request) = @_;

    my $rs = eval { $DB->resultset($request->table)->search($request->filters, 
							    $request->modifiers) };
    QVD::Admin4::Exception->throw(code => ($DB->storage->_dbh->state || 4,
				  message => "$@")) if $@;
   { total => ($rs->is_paged ? $rs->pager->total_entries : $rs->count), 
     rows => [$rs->all] };
}

sub update
{
    my ($self,$request,%modifiers) = @_;
    my $result = $self->select($request);
    my $failures = {};

    my $conditions = $modifiers{conditions} // [];
    my $methods_for_nested_queries = $modifiers{methods_for_nested_queries} // [];

    for my $obj (@{$result->{rows}})
    {
	eval { $self->$_($obj) for @$conditions;
	       $DB->txn_do( sub { eval { $obj->update($request->arguments) };
				  QVD::Admin4::Exception->throw(code => ($DB->storage->_dbh->state || 4),
								message => "$@") if $@;
				  $self->update_related_objects($request,$obj);
				  $self->$_($request,$obj) for @$methods_for_nested_queries } );

	       if ($@) { $failures->{$obj->id} = ($@->can('code') ? $@->code : 4); }
	}
    }
    QVD::Admin4::Exception->throw(code => 1, failures => $failures) if %$failures;
    $result->{rows} = [];
    $result;
}

sub delete
{
    my ($self,$result,%modifiers) = @_;
    my $failures = {};

    my $conditions = $modifiers{conditions} // [];
    for my $obj (@{$result->{rows}})
    {
         eval { $self->$_($obj) || 
		    QVD::Admin4::Exception->throw(code => 16)
		    for @$conditions; 
		$obj->delete };
	 print $@ if $@;
	 if ($@) { $failures->{$obj->id} = ($@->can('code') ? $@->code : 4); }
    }

    QVD::Admin4::Exception->throw(code => 1, failures => $failures) if %$failures;
    $result->{rows} = [];
    $result;
}

sub create
{
    my ($self,$request,%modifiers) = @_;
    my $result = $self->select($request);
    my $failures = {};

    my $conditions = $modifiers{conditions} // [];
    my $methods_for_nested_queries = $modifiers{methods_for_nested_queries} // [];

    eval { $DB->txn_do( sub { $self->$_($request) || QVD::Admin4::Exception->throw(code => 17)
				  for @$conditions;
			      my $obj = $DB->resultset($request->table)->create($request->arguments);
			      $self->create_related_objects($request,$obj);
			      $self->$_($request,$obj) for @$methods_for_nested_queries  } ) };

    print $@ if $@;
    QVD::Admin4::Exception->throw(code => ($DB->storage->_dbh->state || 4),
                                  message => "$@") if $@;
    $result->{rows} = [];
    $result;
}

###################################################
#### NESTED QUERIES WHEN CREATING AND UPDATING ####
###################################################

sub update_related_objects
{
    my($self,$request,$obj)=@_;

    my %tables = %{$request->related_objects_arguments};
    for (keys %tables)
    {
	eval { $obj->$_->update($tables{$_}) }; 
	QVD::Admin4::Exception->throw(code => ($DB->storage->_dbh->state || 4),
	                              message => "$@") if $@;
    }    
}

sub update_custom_properties
{
    my($self,$request,$obj)=@_;

    my $nested_queries = $request->nested_queries // return;
    my $custom_prop_queries = $nested_queries->{propertyChanges} // return;
    my $cp_set_query = $custom_prop_queries->{set};
    my $cp_del_query = $custom_prop_queries->{delete}; 

    $self->custom_properties_set($cp_set_query)
	if defined $cp_set_query;

    $self->custom_properties_del($cp_set_query)
	if defined $cp_del_query;
}

sub update_related_tags
{
    my($self,$request,$obj)=@_;

    my $nested_queries = $request->nested_queries // return;
    my $tags_queries = $nested_queries->{tagsChanges} // return;
    my $tags_create_query = $tags_queries->{create};
    my $tags_delete_query = $tags_queries->{delete}; 

    $self->tags_create($tags_create_query)
	if defined $tags_create_query;

    $self->tags_delete($tags_delete_query)
	if defined $tags_delete_query;
}

sub update_role_acls
{
    my($self,$request,$obj)=@_;

    my $nested_queries = $request->nested_queries // return;
    $nested_queries = $nested_queries->{aclsChanges} // return;
    my $roles_assign_query = $nested_queries->{assign_roles};
    my $acls_assign_query = $nested_queries->{assign_acls};
    my $roles_unassign_query = $nested_queries->{unassign_roles}; 
    my $acls_unassign_query = $nested_queries->{unassign_acls}; 

    $self->add_roles_to_role($roles_assign_query)
	if defined $roles_assign_query;

    $self->del_roles_to_role($roles_unassign_query)
	if defined $roles_unassign_query;

    $self->add_acls_to_role($acls_assign_query)
	if defined $acls_assign_query;

    $self->del_acls_to_role($acls_unassign_query)
	if defined $acls_unassign_query;
}

sub update_admin_roles
{
    my($self,$request,$obj)=@_;

    my $nested_queries = $request->nested_queries // return;
    $nested_queries = $nested_queries->{rolesChanges} // return;
    my $roles_assign_query = $nested_queries->{assign_roles};
    my $roles_unassign_query = $nested_queries->{unassign_roles}; 

    $self->add_roles_to_admin($roles_assign_query)
	if defined $roles_assign_query;

    $self->del_roles_to_admin($roles_unassign_query)
	if defined $roles_unassign_query;
}


sub create_related_objects
{
    my ($self,$request,$obj) = @_;
    my $related_args = $request->related_objects_arguments;

    for my $table ($request->dependencies)
    {
	eval { $obj->create_related($table,($related_args->{$table} || {})) };
	print $@ if $@;
	QVD::Admin4::Exception->throw(code => ($DB->storage->_dbh->state || 4),
                                      message => "$@") if $@;
    }
}

sub create_custom_properties
{
    my($self,$request,$obj)=@_;

    my $nested_queries = $request->nested_queries // return;
    my $custom_prop_queries = $nested_queries->{properties} // return;

    $self->custom_properties_set($custom_prop_queries);
}

sub create_related_tags
{
    my($self,$request,$di)=@_;

    $di->osf->delete_tag('head');
    $di->osf->delete_tag($di->version);
    $DB->resultset('DI_Tag')->create({di_id => $di->id, tag => $di->version, fixed => 1});
    $DB->resultset('DI_Tag')->create({di_id => $di->id, tag => 'head'});
    $DB->resultset('DI_Tag')->create({di_id => $di->id, tag => 'default'})
	unless $di->osf->di_by_tag('default');

    my $nested_queries = $request->nested_queries // return;
    my $tags_queries = $nested_queries->{tags} // return;

    $self->tags_create($tags_queries)
}

sub create_role_acls
{
    my($self,$request,$obj)=@_;

    my $nested_queries = $request->nested_queries // return;
    $nested_queries = $nested_queries->{aclsChanges} // return;
    my $roles_assign_query = $nested_queries->{assign_roles};
    my $acls_assign_query = $nested_queries->{assign_acls};

    $self->add_roles_to_role($roles_assign_query)
	if defined $roles_assign_query;

    $self->add_acls_to_role($acls_assign_query)
	if defined $acls_assign_query;
}

sub create_admin_roles
{
    my($self,$request,$obj)=@_;

    my $nested_queries = $request->nested_queries // return;
    $nested_queries = $nested_queries->{roles} // return;

    $self->add_roles_to_admin($nested_queries)
	if defined $nested_queries;
}

#########################
##### NESTED QUERIES ####
#########################

sub custom_properties_set
{
    my ($self,$props,$obj) = @_;

    my $class = ref($obj);     # FIX ME, PLEASE!!!!
    $class =~ s/^QVD::DB::Result::(.+)$/$1/;

    while (my ($key,$value) = each %$props)
    { 
	my $t = $class . "_Property";
	my $k = lc($class) . "_id";
	my $a = {key => $key, value => $value, $k => $obj->id};
	eval { $DB->resultset($t)->update_or_create($a) };

	print $@ if $@;
	QVD::Admin4::Exception->throw(code => ($DB->storage->_dbh->state || 4),
                                      message => "$@") if $@;
    }
}

sub custom_properties_del
{
    my ($self,$props,$obj) = @_;

    for my $key (@$props)
    {
	eval { $obj->search_related('properties', 
				    {key => $key})->delete };
	QVD::Admin4::Exception->throw(code => ($DB->storage->_dbh->state || 4),
                                      message => "$@") if $@;
    }		
}


sub tags_create
{
    my ($self,$tags,$di) = @_;

    for my $tag (@$tags)
    { 	
	eval {  $di->osf->di_by_tag($tag,'1') && QVD::Admin4::Exception->throw(code => 16);
		$di->osf->delete_tag($tag);
		$DB->resultset('DI_Tag')->create({di_id => $di->id, tag => $tag}) };
	QVD::Admin4::Exception->throw(code => ($DB->storage->_dbh->state || 4),
                                      message => "$@") if $@;
    }
}

sub tags_delete
{
    my ($self,$tags,$di) = @_;

    for my $tag (@$tags)
    {
	$tag = eval { $di->search_related('tags',{tag => $tag})->first };
	QVD::Admin4::Exception->throw(code => ($DB->storage->_dbh->state || 4),
                                      message => "$@") if $@;
	$tag || next;
	$tag->fixed && QVD::Admin4::Exception->throw(code => 16);
	($tag->tag eq 'head' || $tag->tag eq 'default') && QVD::Admin4::Exception->throw(code => 16);
	eval { $tag->delete };
	QVD::Admin4::Exception->throw(code => ($DB->storage->_dbh->state || 4),
                                      message => "$@") if $@;
    }		
}

sub add_acls_to_role
{
    my ($self,$acl_ids,$role) = @_;

    for my $acl_id (@$acl_ids)
    { 	
	my $acl = $DB->resultset('ACL')->search(
	    { id => $acl_id })->first;
	QVD::Admin4::Exception->throw(code => 21) 
	    unless $acl; 
	next if $role->is_allowed_to($acl->name);
	$role->has_negative_acl($acl->name) ?
	    $role->unassign_acls($acl->id) :
	    $role->assign_acl($acl->id,1);
    }
}

sub del_acls_to_role
{
    my ($self,$acl_ids,$role) = @_;

    for my $acl_id (@$acl_ids)
    { 	
	my $acl = $DB->resultset('ACL')->search(
	    { id => $acl_id })->first;
	QVD::Admin4::Exception->throw(code => 21)
	    unless $acl; 

	next unless $role->is_allowed_to($acl->name);

	$role->has_positive_acl($acl->name) ?
	    $role->unassign_acls($acl->id) :
	    $role->assign_acl($acl->id,0);
    }
}

sub add_roles_to_role
{
    my ($self,$roles_to_assign,$this_role) = @_;

    for my $role_to_assign_id (@$roles_to_assign)
    { 	
	my $role_to_assign = $DB->resultset('Role')->search(
	    {id => $role_to_assign_id})->first;
	QVD::Admin4::Exception->throw(code => 20) 
	    unless $role_to_assign;

	my @acl_ids = [$role_to_assign->_get_inherited_acls(return_value => 'id')];
	$this_role->unassign_acls(\@acl_ids);
	$this_role->assign_role($role_to_assign->id);
    }
}

sub del_roles_to_role
{
    my ($self,$roles_to_unassign,$this_role) = @_;

    for my $role_to_unassign_id (@$roles_to_unassign)
    { 	
	my $role_to_unassign = $DB->resultset('Role')->search(
	    {id => $role_to_unassign_id})->first;
	QVD::Admin4::Exception->throw(code => 20) 
	    unless $role_to_unassign;
	$this_role->unassign_roles($role_to_unassign->id);
    }

    my %acl_ids = map { $_->id => 1 } $this_role->_get_only_inherited_acls(return_value => 'id');

    defined $acl_ids{$_} || $this_role->unassign_acls($_,0)
    for $this_role->_get_own_acls(return_value => 'id', positive => 0);
}

sub del_roles_to_admin
{
    my ($self,$role_ids,$admin) = @_;
    $DB->resultset('Role_Administrator_Relation')->search(
	{role_id => $role_ids,
	 administrator_id => $admin->id})->delete_all;
}

sub add_roles_to_admin
{
    my ($self,$role_ids,$admin) = @_;


    eval { $DB->resultset('Role_Administrator_Relation')->create(
	       {role_id => $_,
		administrator_id => $admin->id}) } for @$role_ids;
}

#############################
###### AD HOC FUNCTIONS #####
#############################

sub update_with_custom_properties
{
    my ($self,$request) = @_;

    $self->update($request, methods_for_nested_queries => 
		  [qw(update_custom_properties)]);

}

sub create_with_custom_properties
{
    my ($self,$request) = @_;

    $self->create($request, methods_for_nested_queries => 
		  [qw(create_custom_properties)]);

}

sub di_update
{
    my ($self,$request) = @_;

    $self->update($request, methods_for_nested_queries => 
		  [qw(update_custom_properties
                      update_related_tags)]);
}

sub role_update
{
    my ($self,$request) = @_;

    $self->update($request, methods_for_nested_queries => 
		  [qw(update_role_acls)]);
}

sub role_create
{
    my ($self,$request) = @_;

    $self->create($request, methods_for_nested_queries => 
		  [qw(create_role_acls)]);
}

sub admin_update
{
    my ($self,$request) = @_;

    $self->update($request, methods_for_nested_queries => 
		  [qw(update_admin_roles)]);
}

sub admin_create
{
    my ($self,$request) = @_;

    $self->create($request, methods_for_nested_queries => 
		  [qw(create_admin_roles)]);
}

sub vm_delete
{
    my ($self,$request) = @_;
    my $result = $self->select($request);

    $self->delete($result,conditions => [qw(vm_is_stopped)]);
}


sub di_create
{
    my ($self,$request) = @_;
# $di->update({path => $di->id .'-'.$di->path});

  $self->create($request, methods_for_nested_queries => 
		  [qw(create_related_tags)]);
}

sub di_delete {
    my ($self, $request) = @_;

    my $result = $self->select($request);
    $self->delete($request,conditions => [qw(di_no_vm_runtimes 
                                          di_no_head_default_tags)]);
}


sub vm_user_disconnect
{
    my ($self,$request) = @_;
    my $result = $self->select($request);
    my $failures = {};

    for my $obj (@{$result->{rows}})
    {
	eval { $obj->vm_runtime->send_user_abort  };      
	 if ($@) { $failures->{$obj->id} = 18; print $@; }
    }

    QVD::Admin4::Exception->throw(code => 1, failures => $failures) if %$failures;
    $result->{rows} = [];
    $result;
}

sub vm_start
{
    my ($self,$request) = @_;

    my $result = $self->select($request);
    my $failures = {};
    my %host;

    for my $vm (@{$result->{rows}})
    {
	eval { $DB->txn_do(sub {$vm->vm_runtime->can_send_vm_cmd('start') or die;
				$self->vm_assign_host($vm->vm_runtime);
				$vm->vm_runtime->send_vm_start;
				$host{$vm->vm_runtime->host_id}++;}); 
	       $@ or last } for (1 .. 5);

	if ($@) { $failures->{$vm->id} = 18; print $@; }
    }

    notify("qvd_cmd_for_vm_on_host$_") for keys %host;

    QVD::Admin4::Exception->throw(code => 1, failures => $failures) if %$failures;    
    $result->{rows} = [];
    $result;
}

sub vm_stop
{
    my ($self,$request) = @_;

    my $result = $self->select($request);
    my $failures = {};
    my %host;

    for my $vm (@{$result->{rows}})
    {
	eval { $DB->txn_do(sub { if ($vm->vm_runtime->can_send_vm_cmd('stop')) 
				 {
				     $vm->vm_runtime->send_vm_stop;
				     $host{$vm->vm_runtime->host_id}++;
				 }
				 else 
				 {
				     if ($vm->vm_runtime->vm_state eq 'stopped' and
					 $vm->vm_runtime->vm_cmd eq 'start') 
				     {
					 $vm->vm_runtime->update({ vm_cmd => undef });
				     }
				 }
			   });
	       $@ or last } for (1 .. 5);

	if ($@) { $failures->{$vm->id} = 18; print $@; }
    }

    notify("qvd_cmd_for_vm_on_host$_") for keys %host;

    QVD::Admin4::Exception->throw(code => 1, failures => $failures) if %$failures;    
    $result->{rows} = [];
    $result;
}

##########################
### AUXILIAR FUNCTIONS ###
##########################

my $lb;
sub vm_assign_host {
    my ($self, $vmrt) = @_;
    if (!defined $vmrt->host_id) {
        $lb //= do {
            require QVD::L7R::LoadBalancer;
            QVD::L7R::LoadBalancer->new();
        };
        my $free_host = $lb->get_free_host($vmrt->vm) //
            die "Unable to start machine, no hosts available";

        $vmrt->set_host_id($free_host);
    }
}

sub vm_is_stopped
{
    my ($self,$vm) = @_;
    $vm->vm_runtime->vm_state eq 'stopped' ? 
	return 1 : 
	return 0;
}

sub di_no_vm_runtimes
{
    my ($self,$di) = @_;
    $di->vm_runtimes->count == 0;
}

sub di_no_head_default_tags
{
    my ($self,$di) = @_;

    for my $tag (qw/default head/) 
    {
	next unless $di->has_tag($tag);
	my @potentials = grep { $_->id ne $di->id } $di->osf->dis;
	if (@potentials) {
	    my $new_di = $potentials[-1];
	    $DB->resultset('DI_Tag')->create({di_id => $new_di->id, tag => $tag});
	}
    }
    return 1;
}


##################################
## GENERAL STATISTICS FUNCTIONS ##
##################################

my $JSON_TO_DBIX = { User => { blocked => 'me.blocked',
                               tenant  => 'me.tenant_id'}, # FIX ME, PLEASE
                     VM   => { blocked => 'vm_runtime.blocked',
			       state   => 'vm_runtime.vm_state',
                               tenant => 'user.tenant_id' },
		     Host => { blocked => 'runtime.blocked',
			       state   => 'runtime.state' },
		     OSF  => { tenant => 'me.tenant_id' },
		     DI   => { blocked => 'me.blocked',
                               tenant => 'osf.tenant_id'}};

sub qvd_objects_statistics
{
    my $self = shift;
    my $STATISTICS = {};

    $STATISTICS->{$_}->{total} = 
	$self->get_total_number_of_qvd_objects($_)
	for qw(User VM Host OSF DI);

    $STATISTICS->{$_}->{blocked} = 
	$self->get_number_of_blocked_qvd_objects($_)
	for qw(User VM Host DI);

    $STATISTICS->{$_}->{running} = 
	$self->get_number_of_running_qvd_objects($_)
	for qw(VM Host);

    $STATISTICS->{VM}->{expiration} = 
	$self->get_vms_with_expitarion_date();

    $STATISTICS->{Host}->{population} = 
	$self->get_the_most_populated_hosts();

    $STATISTICS;
}

sub get_total_number_of_qvd_objects
{
    my ($self,$qvd_obj) = @_;
    $qvd_obj =~ /^User|VM|Host|OSF|DI$/ ||
	QVD::Admin4::Exception->throw(code=>'4');

    $DB->resultset($qvd_obj)->search(
	{  }, {})->count;
}

sub get_number_of_blocked_qvd_objects
{
    my ($self,$qvd_obj) = @_;
    $qvd_obj =~ /^User|VM|Host|DI$/ ||
	QVD::Admin4::Exception->throw(code=>'4');

    my $filter = $JSON_TO_DBIX->{$qvd_obj}->{blocked};
    my ($related_table) = $filter =~ /^(.+)\.(.+)$/;
    my $join = $related_table eq 'me' ? 
	[] : [$related_table];


    $DB->resultset($qvd_obj)->search(
	{ $filter => 'true' }, {join => $join})->count;
}

sub get_number_of_running_qvd_objects
{
    my ($self,$qvd_obj) = @_;
    $qvd_obj =~ /^VM|Host$/ ||
	QVD::Admin4::Exception->throw(code=>'4');
    my $filter = $JSON_TO_DBIX->{$qvd_obj}->{state};
    my ($related_table) = $filter =~ /^(.+)\.(.+)$/;
    my $join = $related_table eq 'me' ? 
	[] : [$related_table];

    $DB->resultset($qvd_obj)->search(
	{ $filter => 'running' },{join => $join})->count;
}

sub get_vms_with_expitarion_date
{
    my ($self) = @_;

    my $is_not_null = 'IS NOT NULL';
    my $rs = $DB->resultset('VM')->search(
	{ -or => [ { 'vm_runtime.vm_expiration_hard'  => \$is_not_null }, 
		   { 'vm_runtime.vm_expiration_soft'  => \$is_not_null } ] },
	{ join => [qw(vm_runtime)]});

    my $now = DateTime->now();

    [ sort { DateTime->compare($a->{expiration},$b->{expiration}) }
      grep { sum(values %{$_->{remaining_time}}) > 0 }
      map {{ name            => $_->name, 
	     id              => $_->id,
	     expiration      => $_->vm_runtime->vm_expiration_hard,
	     remaining_time  => $self->calculate_date_time_difference($now,
								      $_->vm_runtime->vm_expiration_hard) }}

      $rs->all ];
}

sub calculate_date_time_difference
{
    my ($self,$now,$then) = @_;
    my @time_units = qw(days hours minutes seconds);
    my %time_difference;

    @time_difference{@time_units} = $then->subtract_datetime($now)->in_units(@time_units);
    \%time_difference;
}

sub get_the_most_populated_hosts
{
    my ($self) = @_;

    my $rs = $DB->resultset('Host')->search({ 'vms.vm_state' => 'running'}, 
					    { distinct => 1, 
                                              join => [qw(vms)] });
    return [] unless $rs->count;

    my @hosts = sort { $b->{number_of_vms} <=> $a->{number_of_vms} }
                map {{ name          => $_->name, 
		       id            => $_->id,
		       number_of_vms => $_->vms_connected }} 
                $rs->all;
    my $array_limit = $#hosts > 5 ? 5 : $#hosts;    
    return [@hosts[0 .. $array_limit]];
}

1;

