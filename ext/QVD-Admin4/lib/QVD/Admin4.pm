package QVD::Admin4;

use 5.010;
use strict;
use warnings;
use Moo;
use QVD::DB;
use QVD::DB::Simple;
use QVD::Config;
use File::Copy qw(copy move);
use Config::Properties;
use QVD::Admin4::Exception;
use DateTime;
use List::Util qw(sum);
use File::Basename qw(basename dirname);
use QVD::Admin4::REST::Model;
use QVD::Admin4::REST::Request;

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

    QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
				  message => "$@") if $@;

    { total => ($rs->is_paged ? $rs->pager->total_entries : $rs->count), 
      rows => [$rs->all],
      extra => $self->get_extra_info_from_related_views($request) };
}


sub get_extra_info_from_related_views
{
    my ($self,$request) = @_;
    my $extra = {};
    
    my $view_name = $request->related_view;
    return $extra unless $view_name;

    my $vrs = eval { $DB->resultset($view_name)->search() };
    QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
				  message => "$@") if $@;
    $extra->{$_->id} = $_ for $vrs->all;        
    $extra;
}

sub update
{
    my ($self,$request,%modifiers) = @_;
    my $result = $self->select($request);
    QVD::Admin4::Exception->throw(code => 25) unless $result->{total};
    my $failures = {}; 
    my $conditions = $modifiers{conditions} // [];

    for my $obj (@{$result->{rows}})
    {
	eval { $DB->txn_do( sub { $self->$_($obj) || QVD::Admin4::Exception->throw(code => 16)
				      for @$conditions;

				  eval { $obj->update($request->arguments) };
				  QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
								message => "$@") if $@;
				  $self->update_related_objects($request,$obj);
				  $self->exec_nested_queries($request,$obj);} ) };
	print $@ if $@;
	if ($@) { $failures->{$obj->id} = ($@->can('code') ? $@->code : 4); }
    }
    QVD::Admin4::Exception->throw(code => 1, failures => $failures) if %$failures;
    $result->{rows} = [];
    $result;
}


sub delete
{
    my ($self,$request,%modifiers) = @_;
    my $result = $self->select($request);
    QVD::Admin4::Exception->throw(code => 25) unless $result->{total};

    my $failures = {};
    my $conditions = $modifiers{conditions} // [];

    for my $obj (@{$result->{rows}})
    {
         eval { $self->$_($obj) || QVD::Admin4::Exception->throw(code => 16)
		    for @$conditions; 
		eval { $obj->delete };
		QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
					      message => "$@") if $@ };
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
    my $result;
    my $failures = {};
    my $conditions = $modifiers{conditions} // [];

    $DB->txn_do( sub { $self->$_($request) || QVD::Admin4::Exception->throw(code => 17)
			   for @$conditions;
		       my $obj = eval {$DB->resultset($request->table)->create($request->arguments)};
		       print $@ if $@;
		       QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
						     message => "$@") if $@;

		       $self->create_related_objects($request,$obj);
		       $self->exec_nested_queries($request,$obj);
		       $result->{rows} = [ $obj ] } );
    $result->{total} = 1;
    $result->{extra} = {};
    $result;
}

sub create_or_update
{
    my ($self,$request) = @_;
    my $result;
    my $failures = {};

    $DB->txn_do( sub { my $obj = eval {$DB->resultset($request->table)->update_or_create($request->arguments)};
		       print $@ if $@;
		       QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
						     message => "$@") if $@;
		       $result->{rows} = [ $obj ] } );
    $result->{total} = 1;
    $result->{extra} = {};
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
	QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
	                              message => "$@") if $@;
    }    
}

sub create_related_objects
{
    my ($self,$request,$obj) = @_;
    my $related_args = $request->related_objects_arguments;

    for my $table ($request->dependencies)
    {
	eval { $obj->create_related($table,($related_args->{$table} || {})) };
	print $@ if $@;
	QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
                                      message => "$@") if $@;
    }
}

sub exec_nested_queries
{
    my($self,$request,$obj)=@_;

    my %nq = %{$request->nested_queries};
    for (keys %nq)
    {
	$self->$_($nq{$_},$obj); 
    }    
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
	QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
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
	QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
                                      message => "$@") if $@;
    }		
}


sub tags_create
{
    my ($self,$tags,$di) = @_;

    QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
				  message => "$@") if $@;

    for my $tag (@$tags)
    { 	
	eval {  $di->osf->di_by_tag($tag,'1') && QVD::Admin4::Exception->throw(code => 16);
		$di->osf->delete_tag($tag);
		$DB->resultset('DI_Tag')->create({di_id => $di->id, tag => $tag}) };
	QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
                                      message => "$@") if $@;
    }
}

sub tags_delete
{
    my ($self,$tags,$di) = @_;

    for my $tag (@$tags)
    {
	$tag = eval { $di->search_related('tags',{tag => $tag})->first };
	QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
                                      message => "$@") if $@;
	$tag || next;
	$tag->fixed && QVD::Admin4::Exception->throw(code => 16);
	($tag->tag eq 'head' || $tag->tag eq 'default') && QVD::Admin4::Exception->throw(code => 16);
	eval { $tag->delete };
	QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
                                      message => "$@") if $@;
    }		
}

sub add_acls_to_role
{
    my ($self,$acl_names,$role) = @_;

    for my $acl_name (@$acl_names)
    { 	
	next if $role->has_own_positive_acl($acl_name);
	$role->has_own_negative_acl($acl_name) ?
	    $self->switch_acl_sign_in_role($role,$acl_name) :
	    $self->assign_acl_to_role($role,$acl_name,1);
    }
}

sub del_acls_to_role
{
    my ($self,$acl_names,$role) = @_;

    for my $acl_name (@$acl_names)
    { 	
	next unless $role->is_allowed_to($acl_name);
	
	if ($role->has_own_positive_acl($acl_name)) 
	{
	    $self->unassign_acl_to_role($role,$acl_name);
	}

	if ($role->has_inherited_acl($acl_name))
	{
	    $self->assign_acl_to_role($role,$acl_name,0);
	}
    }
}

sub add_roles_to_role
{
    my ($self,$roles_to_assign,$this_role) = @_;

    for my $role_to_assign_id (@$roles_to_assign)
    {
	$self->assign_role_to_role($this_role,$role_to_assign_id);
	my $nested_role;
	for my $neg_acl_name ($this_role->get_negative_own_acl_names)
	{
	    $nested_role //= $DB->resultset('Role')->find({id => $role_to_assign_id});
	    $self->unassign_acl_to_role($this_role,$neg_acl_name) 
		 if $nested_role->is_allowed_to($neg_acl_name);
	}
    }
}

sub del_roles_to_role
{
    my ($self,$roles_to_unassign,$this_role) = @_;

    $self->unassign_role_to_role($this_role,$_) 
	for @$roles_to_unassign;

    $this_role->reload_full_acls_inheritance_tree;
    for my $neg_acl_name ($this_role->get_negative_own_acl_names)
    {
	$self->unassign_acl_to_role($this_role,$neg_acl_name) 
	    unless $this_role->has_inherited_acl($neg_acl_name);

    }
}

#############

sub switch_acl_sign_in_role
{
    my ($self,$role,$acl_name) = @_;

    my $acl_id = eval { $DB->resultset('ACL')->find({name => $acl_name})->id }
    // QVD::Admin4::Exception->throw(code=>'21');

    my $acl_role_rel = eval { $DB->resultset('ACL_Role_Relation')->find(
				  {role_id => $role->id,
				   acl_id => $acl_id }) }
    // QVD::Admin4::Exception->throw(code=>'21');

    eval { $acl_role_rel->update({ positive => $acl_role_rel->positive ? 0 : 1 }) };

    print $@ if $@;
    QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
				  message => "$@") if $@;
}


sub assign_acl_to_role
{
    my ($self,$role,$acl_name,$positive) = @_;

    my $acl_id = eval { $DB->resultset('ACL')->find({name => $acl_name})->id }
    // QVD::Admin4::Exception->throw(code=>'21');
    eval { $role->create_related('acl_rels', { acl_id => $acl_id,
					       positive => $positive }) };
    print $@ if $@;
    QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
				  message => "$@") if $@;
}

sub unassign_acl_to_role
{
    my ($self,$role,$acl_name) = @_;

    my $acl_id = eval { $DB->resultset('ACL')->find({name => $acl_name})->id }
    // QVD::Admin4::Exception->throw(code=>'21');
    for ($role->search_related('acl_rels', { acl_id => $acl_id })->all)
    {
	eval { $_->delete };
	print $@ if $@;
	QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
				      message => "$@") if $@;
    } 	
}

sub assign_role_to_role
{
    my ($self,$inheritor_role,$inherited_role_id) = @_;

    my $inherited_role = $DB->resultset('Role')->find({id => $inherited_role_id}) //
	QVD::Admin4::Exception->throw(code => 20);

    $inheritor_role->id eq $_ && QVD::Admin4::Exception->throw(code => 26)
	for $inherited_role->get_all_inherited_role_ids;

    eval { $inheritor_role->create_related('role_rels', { inherited_id => $inherited_role_id }) };

    print $@ if $@;
    QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
				  message => "$@") if $@;
}

sub unassign_role_to_role
{
    my ($self,$role,$role_ids) = @_;

    my $rs = $role->search_related('role_rels', { inherited_id => $role_ids });
    for ($rs->all)
    {
	eval { $_->delete };
	print $@ if $@;
	QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
				      message => "$@") if $@;
    }
}

###########

sub del_roles_to_admin
{
    my ($self,$role_ids,$admin) = @_;

    eval{

	$DB->resultset('Role_Administrator_Relation')->search(
	    {role_id => $role_ids,
	     administrator_id => $admin->id})->delete_all
    };

    QVD::Admin4::Exception->throw(code => $DB->storage->_dbh->state,
				  message => "$@") if $@
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


sub vm_delete
{
    my ($self,$request) = @_;

    $self->delete($request,conditions => [qw(vm_is_stopped)]);
}


sub di_create
{
    my ($self,$request) = @_;

    my $images_path  = cfg('path.storage.images');
    QVD::Admin4::Exception->throw(code=>'31')
	unless -d $images_path;

    my $staging_path = cfg('path.storage.staging');
    QVD::Admin4::Exception->throw(code=>'32')
	unless -d $staging_path;

    my $staging_file = basename($request->arguments->{path});
    QVD::Admin4::Exception->throw(code=>'33')
	unless -e "$staging_path/$staging_file";

    my $result = $self->create($request, methods_for_nested_queries => 
			     [qw(create_custom_properties create_related_tags)]);
    my $di = @{$result->{rows}}[0];

    eval {

    $di->osf->delete_tag('head');
    $di->osf->delete_tag($di->version);
    $DB->resultset('DI_Tag')->create({di_id => $di->id, tag => $di->version, fixed => 1});
    $DB->resultset('DI_Tag')->create({di_id => $di->id, tag => 'head'});
    $DB->resultset('DI_Tag')->create({di_id => $di->id, tag => 'default'})
	unless $di->osf->di_by_tag('default')
    };

    my $images_file  = $di->id . '-' . $staging_file;
    $di->update({path => $images_file});

    for (1 .. 5)
    {
	eval { copy("$staging_path/$staging_file","$images_path/$images_file") };
	$@ ? print $@ : last;
    }
    if ($@) { $di->delete; QVD::Admin4::Exception->throw(code=>'30');}

    $result;
}

sub di_delete {
    my ($self, $request) = @_;

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
	print $@ if $@;
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

######################################
## GENERAL FUNCTIONS; WITHOUT REQUEST
######################################


sub get_properties_by_qvd_object
{
   my ($self,$admin,$json) = @_;
    my $qvd_object = lc $json->forze_filter_deletion('qvd_object') //
	QVD::Admin4::Exception->throw(code=>'10');
   $qvd_object =~ /^user|vm|host|osf|di$/ || 
       QVD::Admin4::Exception->throw(code=>'41');

   my %tables = (user => 'User', vm => 'VM',
                 host => 'Host', osf => 'OSF', di => 'DI');

   my $model = 
       QVD::Admin4::REST::Model->new(current_qvd_administrator => $admin,
				     qvd_object => $tables{$qvd_object},
				     type_of_action => 'list');

    my $req = QVD::Admin4::REST::Request->new(qvd_object_model => $model, 
					      json_wrapper => $json);
   use Data::Dumper; print Dumper $DB->resultset('User_Properties_List_View')->search({},{ bind => [1] })->first->properties;
   my $view = $self->get_extra_info_from_related_views($req);
   my @props = map { keys %{$_->properties} } values %$view;
   my %props = map { $_ => 1 } @props;

   { total => scalar keys %props, 
     rows => [sort keys %props ] };
}


sub current_admin_setup
{
    my ($self,$administrator,$json_wrapper) = @_;

    my $f =
        sub { my $obj = shift;
              my @methods = qw(field qvd_object view_type                                                                                                                                     
                               device_type property);
              my $out; $out .= $obj->$_ for @methods; $out; };

    my @tenant_views = $DB->resultset('Tenant_Views_Setup')->search(
        {tenant_id => $administrator->tenant_id})->all;
    my @admin_views = $DB->resultset('Administrator_Views_Setup')->search(
        {administrator_id => $administrator->id})->all;
    my %views = map { $f->($_) => $_ } @tenant_views;
    $views{$f->($_)} = $_ for  @admin_views;

   { acls => [ $administrator->acls ],
     views => [ map { { $_->get_columns } } values %views ]};
}

sub get_acls_in_admins
{
    my ($self,$admin,$json_wrapper) = @_;
    my $admin_id = $json_wrapper->get_filter_value('admin_id') //
	QVD::Admin4::Exception->throw(code=>'10');
    $admin_id = [$admin_id] unless ref($admin_id);
    
    my $acls_info;

    for my $role (map { $_->role } $DB->resultset('Role_Administrator_Relation')->search(
		      {administrator_id => $admin_id})->all)
    {
	my $inherited_acls_tree = $role->get_full_acls_inheritance_tree;
	for my $acl_id (keys %{$inherited_acls_tree->{$role->id}->{iacls}})
	{
	    $acls_info->{$acl_id} = $inherited_acls_tree->{$role->id}->{iacls}->{$acl_id};
	    $acls_info->{$acl_id}->{roles} //= {};
            $acls_info->{$acl_id}->{roles}->{$role->id} =
                $inherited_acls_tree->{$role->id}->{name};
	}
    }

    my $acls_name = $json_wrapper->get_filter_value('acl_name') // '%';
    my $acls_rs = $DB->resultset('ACL')->search({id => [keys %$acls_info], 
						 name => { like => $acls_name }},
	{ order_by => { ($json_wrapper->order_direction || '-asc') => 
			($json_wrapper->order_criteria || []) },
	  page => ($json_wrapper->offset || 1),
	  rows => ($json_wrapper->block || 10000) });

   { total => ($acls_rs->is_paged ? $acls_rs->pager->total_entries : $acls_rs->count), 
     rows => [map { $acls_info->{$_->id} } $acls_rs->all] };
}

sub get_acls_in_roles
{
    my ($self,$admin,$json_wrapper) = @_;
    my $role_id = $json_wrapper->get_filter_value('role_id') //
	QVD::Admin4::Exception->throw(code=>'10');
    $role_id = [$role_id] unless ref($role_id);
    
    my $acls_info;

    for my $role ($DB->resultset('Role')->search({id => $role_id})->all)
    {
	my $inherited_acls_tree = $role->get_full_acls_inheritance_tree;
	for my $acl_id (keys %{$inherited_acls_tree->{$role->id}->{iacls}})
	{
	    $acls_info->{$acl_id} = $inherited_acls_tree->{$role->id}->{iacls}->{$acl_id};
	    $acls_info->{$acl_id}->{roles}->{$role->id} = $role->name if
                defined $inherited_acls_tree->{$role->id}->{acls}->{1}->{$acl_id};

            $acls_info->{$acl_id}->{roles}->{$_->{id}} = $_->{name}
                for grep { defined $_->{iacls}->{$acl_id} }
                    values %{$inherited_acls_tree->{$role->id}->{roles}};
	}
    }

    my $acls_name = $json_wrapper->get_filter_value('acl_name') // '%';
    my $acls_rs = $DB->resultset('ACL')->search({id => [keys %$acls_info], 
						 name => { like => $acls_name }},
	{ order_by => { ($json_wrapper->order_direction || '-asc') => 
			($json_wrapper->order_criteria || []) },
	  page => ($json_wrapper->offset || 1),
	  rows => ($json_wrapper->block || 10000) });

   { total => ($acls_rs->is_paged ? $acls_rs->pager->total_entries : $acls_rs->count), 
     rows => [map { $acls_info->{$_->id} } $acls_rs->all] };
}

sub get_number_of_acls_in_role
{
    my ($self,$admin,$json_wrapper) = @_;
    $self->get_number_of_acls_in_role_or_admin('Role',$json_wrapper);
}

sub get_number_of_acls_in_admin
{
    my ($self,$admin,$json_wrapper) = @_;
    $self->get_number_of_acls_in_role_or_admin('Administrator',$json_wrapper);
}

sub get_number_of_acls_in_role_or_admin
{
    my ($self,$table,$json_wrapper) = @_;

    my $acl_patterns = $json_wrapper->get_filter_value('acl_pattern') //
	QVD::Admin4::Exception->throw(code=>'10');
    $acl_patterns = ref($acl_patterns) ? $acl_patterns : [$acl_patterns];
    my $id = $json_wrapper->get_filter_value($table eq 'Role' ? 'role_id' : 'admin_id') // 
	QVD::Admin4::Exception->throw(code=>'10'); 

    my $object = $DB->resultset($table)->find({ id => $id }) //
	QVD::Admin4::Exception->throw(code=>  $table eq 'Role' ? 20 : 40 );

    my $output;
    for my $acl_pattern (@$acl_patterns)
    {
	my $rs = $DB->resultset('ACL')->search({ name => { ilike => $acl_pattern }});
	my $total_number_of_acls = $rs->count;
	my @available_acls_in_role = grep { $object->is_allowed_to($_->name) } $rs->all;
	my $available_acls_in_role = @available_acls_in_role;
 
	$output->{$acl_pattern} = 
	{ total => $total_number_of_acls,
	  effective => $available_acls_in_role };
    }

    $output;
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
    my ($self,$admin) = @_;

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
