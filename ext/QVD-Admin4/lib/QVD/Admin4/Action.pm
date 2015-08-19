package QVD::Admin4::Action;
use strict;
use warnings;
use Moo;
use QVD::Admin4::Exception;

# This class implements an action supported by the API.
# The object provides some minimal info about the action
# The object can be built only if the action requested 
# is supported by the API.

# This mandatory paramenter identifies the action
# supported by the API that will be created

has 'name', is => 'ro', isa => sub {}, required => 1;

# $ACTIONS stores the list of actions supported by the API
# For all them, minimal info is stored:
# a) type_of_action (ad_hoc is the generic value for non standard actions) 
# b) qvd_object (not available form non standard actions)
# c) acls (needed for execute this action)
# d) admin4method (method to execute in order to execute the action) 

my $ACTIONS =
{

sources_in_log => {type_of_action => 'ad_hoc',
		       admin4method => 'sources_in_log',
		  acls => [qr/^(log\.see-(main|details)\.|(administrator|di|host|osf|role|tenant|user|vm)\.see\.log)$/],},

log_get_list => {type_of_action => 'list',
		  admin4method => 'select',
		  acls => [qr/^(log\.see-(main|details)\.|(administrator|di|host|osf|role|tenant|user|vm)\.see\.log)$/],
		  qvd_object => 'Log'},

log_get_details => {type_of_action => 'list',
		    admin4method => 'select',
		    acls => [qr/^log\.see-details\./],
		    qvd_object => 'Log'},

dis_in_staging => { type_of_action =>  'ad_hoc',
		    acls => [qr/^di\.create\./],
		    admin4method => 'dis_in_staging'},

config_ssl => { type_of_action =>  'ad_hoc',
		acls => [qr/^config\.update\./],
		admin4method => 'config_ssl'},

config_get => { type_of_action =>  'ad_hoc',
		acls => [qr/^config\.qvd\./],
		admin4method => 'config_get'},

config_preffix_get => { type_of_action =>  'ad_hoc',
			acls => [qr/^config\.qvd\./],
			admin4method => 'config_preffix_get'},

config_set => { type_of_action =>  'create_or_update',
		qvd_object => 'Config',
		acls => [qr/^config\.qvd\./],
		admin4method => 'config_set'},

config_default => { type_of_action =>  'delete',
		   qvd_object => 'Config',
		   acls => [qr/^config\.qvd\./],
		   admin4method => 'config_default'},

config_delete => { type_of_action =>  'delete',
		   qvd_object => 'Config',
		   acls => [qr/^config\.qvd\./],
		   admin4method => 'config_delete'},

user_get_list => {type_of_action => 'list',
		  admin4method => 'select',
		  acls => [qr/^(user\.see-main\.|[^.]+\.see\.user-list)$/],
		  qvd_object => 'User'},

user_tiny_list => {type_of_action => 'tiny',
		   admin4method => 'select',
		   acls => [qr/^vm\.(create\.|filter\.user)$/],
		   qvd_object => 'User'},

user_all_ids => { type_of_action => 'all_ids',
		  admin4method => 'select',
		  acls => [qr/^user\.[^.]+-massive\.|user\.see-main\./],
		  qvd_object => 'User'},

user_get_details => { type_of_action => 'details',
		      admin4method => 'select',
		      channels => [qw(user_state_changed vm_state_changed user_state_changed)],
		      acls => [qr/^user\.see-details\./],
		      qvd_object => 'User' },

user_get_state => { type_of_action => 'state',
		    admin4method => 'select',
		    acls => [qr/^user\.see\.vm-list-state$/],
		    qvd_object => 'User' },

user_update => { type_of_action => 'update',
		 admin4method => 'update',
		 acls => [qr/^user\.update\./],
		 qvd_object => 'User' },

user_create => { type_of_action => 'create',
		 admin4method => 'create',
		 acls => [qr/^user\.create\.$/],
		 qvd_object => 'User'},

user_delete => { type_of_action => 'delete',
		 admin4method => 'delete',
		 acls => [qr/^user\.delete\./],
		 qvd_object => 'User'},

user_get_property_list => {type_of_action => 'list',
		  admin4method => 'select',
		  acls => [qr/^(user\.see\.properties)$/],
		  qvd_object => 'User_Property_List'},

user_create_property_list => { type_of_action => 'create',
		 admin4method => 'create',
		 acls => [qr/^user\.update\.properties-create$/],
		 qvd_object => 'User_Property_List'},

user_delete_property_list => { type_of_action => 'delete',
		 admin4method => 'delete',
		 acls => [qr/^user\.update\.properties-delete$/],
		 qvd_object => 'User_Property_List'},

vm_get_list => { type_of_action => 'list',
		 admin4method => 'select',
		 acls => [qr/^(vm\.see-main\.|[^.]+\.see\.vm-list)$/],
		 qvd_object => 'VM'},

vm_all_ids => { type_of_action => 'all_ids',
		admin4method => 'select',
		acls => [qr/^vm\.[^.]+-massive\.|(vm\.see-main\.|[^.]+\.see\.vm-list)/],
		qvd_object => 'VM'},

vm_tiny_list => { type_of_action => 'tiny',
		  admin4method => 'select',
		   acls => [qr/^(host|osf)\.filter\.vm$/],
		  qvd_object => 'VM'},

vm_get_details => { type_of_action => 'details',
		    admin4method => 'select',
		    channels => [qw(vm_state_changed user_state_changed)],
		    acls => [qr/^vm\.see-details\./],
		    qvd_object => 'VM'},

vm_get_state => { type_of_action => 'state',
		  admin4method => 'select',
		  acls => [qr/^vm\.see\.state$/,qr/^vm\.see\.user-state$/],
		  qvd_object => 'VM'},

vm_update => { type_of_action => 'update',
	       admin4method => 'update',
	       acls => [qr/^vm\.update\./],
	       qvd_object => 'VM'},

vm_user_disconnect => { type_of_action => 'exec',
			admin4method => 'vm_user_disconnect',
			acls => [qr/^vm\.update(-massive)?\.disconnect-user$/],
			qvd_object => 'VM'},

vm_start => { type_of_action => 'exec',
	      admin4method => 'vm_start',
	     acls => [qr/^vm\.update(-massive)?\.state$/],
	      qvd_object => 'VM'},

vm_stop => { type_of_action => 'exec',
	     admin4method => 'vm_stop',
	     acls => [qr/^(vm\.update(-massive)?\.state|host\.update(-massive)?\.stop-vms)$/],
	     qvd_object => 'VM' },

vm_create => { type_of_action => 'create',
	       admin4method => 'create',
	       acls => [qr/^vm\.create\./],
	       qvd_object => 'VM'},

vm_delete => { type_of_action => 'delete',
	       admin4method => 'vm_delete',
	       acls => [qr/^vm\.delete\./],
	       qvd_object => 'VM'},

vm_get_property_list => {type_of_action => 'list',
		  admin4method => 'select',
		  acls => [qr/^(vm\.see\.properties)$/],
		  qvd_object => 'VM_Property_List'},

vm_create_property_list => { type_of_action => 'create',
		 admin4method => 'create',
		 acls => [qr/^vm\.update\.properties-create$/],
		 qvd_object => 'VM_Property_List'},

vm_delete_property_list => { type_of_action => 'delete',
		 admin4method => 'delete',
		 acls => [qr/^vm\.update\.properties-delete$/],
		 qvd_object => 'VM_Property_List'},

host_get_list => { type_of_action => 'list',
		   admin4method => 'select',
		   acls => [qr/^host\.see-main\./],
		   qvd_object => 'Host'},

host_all_ids => { type_of_action => 'all_ids',
		  admin4method => 'select',
		  acls => [qr/^host\.[^.]+-massive\.|host\.see-main\./],
		  qvd_object => 'Host'},

host_tiny_list => { type_of_action => 'tiny',
		    admin4method => 'select',
		    acls => [qr/^vm\.filter\.host$/],
		    qvd_object => 'Host'},

host_get_details => { type_of_action => 'details',
		      admin4method => 'select',
		      channels => [qw(host_state_changed vm_state_changed)],
		      acls => [qr/^host\.see-details\./],
		      qvd_object => 'Host'},

host_get_state => { type_of_action => 'state',
		    admin4method => 'select',
		   acls => [qr/^host\.see\.vm-list-state$/],
		    qvd_object => 'Host'},

host_update => { type_of_action => 'update', 
		 admin4method => 'update',
		   acls => [qr/^host\.update\./],
		 qvd_object => 'Host' },

host_create => { type_of_action => 'create',
		 admin4method => 'create',
		   acls => [qr/^host\.create\./],
		 qvd_object => 'Host'},

host_delete => { type_of_action => 'delete',
		 admin4method => 'delete',
		 acls => [qr/^host\.delete\./],
		 qvd_object => 'Host'},

host_get_property_list => {type_of_action => 'list',
		  admin4method => 'select',
		  acls => [qr/^(host\.see\.properties)$/],
		  qvd_object => 'Host_Property_List'},

host_create_property_list => { type_of_action => 'create',
		 admin4method => 'create',
		 acls => [qr/^host\.update\.properties-create$/],
		 qvd_object => 'Host_Property_List'},

host_delete_property_list => { type_of_action => 'delete',
		 admin4method => 'delete',
		 acls => [qr/^host\.update\.properties-delete$/],
		 qvd_object => 'Host_Property_List'},

osf_get_list => { type_of_action => 'list',
		  admin4method => 'select',
		  acls => [qr/^osf\.see-main\./],
		  qvd_object => 'OSF'},

osf_all_ids => { type_of_action => 'all_ids',
		 admin4method => 'select',
		 acls => [qr/^osf\.[^.]+-massive\.|osf\.see-main\./],
		 qvd_object => 'OSF'},

osf_tiny_list => { type_of_action => 'tiny',
		   admin4method => 'select',
		   acls => [qr/^(di|vm)\.(create\.|filter\.(di|vm))$/],
		   qvd_object => 'OSF'},

osf_get_details => { type_of_action => 'details',
		     admin4method => 'select',
		     channels => [qw(vm_created_or_deleted di_created_or_delated)],
		     acls => [qr/^osf\.see-details\./],
		     qvd_object => 'OSF'},

osf_update => {  type_of_action => 'update',
		 admin4method => 'update',
		 acls => [qr/^osf\.update\./],
		 qvd_object => 'OSF' },

osf_create => { type_of_action => 'create',
		admin4method => 'create',
		acls => [qr/^osf\.create\./],
		qvd_object => 'OSF'},

osf_delete => { type_of_action => 'delete',
		admin4method => 'delete',
		acls => [qr/^osf\.delete\./],
		qvd_object => 'OSF'},

osf_get_property_list => {type_of_action => 'list',
		  admin4method => 'select',
		  acls => [qr/^(osf\.see\.properties)$/],
		  qvd_object => 'OSF_Property_List'},

osf_create_property_list => { type_of_action => 'create',
		 admin4method => 'create',
		 acls => [qr/^osf\.update\.properties-create$/],
		 qvd_object => 'OSF_Property_List'},

osf_delete_property_list => { type_of_action => 'delete',
		 admin4method => 'delete',
		 acls => [qr/^osf\.update\.properties-delete$/],
		 qvd_object => 'OSF_Property_List'},

di_get_list => { type_of_action => 'list',
		 admin4method => 'select',
		 acls => [qr/^(di\.see-main\.|[^.]+\.see\.di-list)$/],
		 qvd_object => 'DI'},

di_all_ids => { type_of_action => 'all_ids',
		admin4method => 'select',
		acls => [qr/^di\.[^.]+-massive\.|(di\.see-main\.|[^.]+\.see\.di-list)/],
		qvd_object => 'DI'},

di_tiny_list => { type_of_action => 'tiny',
		  admin4method => 'select',
		  acls => [qr/^osf\.filter\.di$/],
		  qvd_object => 'DI'},

di_get_details => { type_of_action => 'details',
		    admin4method => 'select',
		     channels => [qw(vm_created_or_deleted)],
		    acls => [qr/^di\.see-details\./],
		    qvd_object => 'DI'},

di_update => { type_of_action => 'update',
	       admin4method => 'update',
	       acls => [qr/^di\.update\./],
	       qvd_object => 'DI'},

di_create => { type_of_action => 'create',
	       admin4method => 'di_create',
	       acls => [qr/^di\.create\./],
	       qvd_object => 'DI'},

di_delete => { type_of_action => 'delete',
	       admin4method => 'di_delete',
	       acls => [qr/^di\.delete\./],
	       qvd_object => 'DI'},

di_get_property_list => {type_of_action => 'list',
		  admin4method => 'select',
		  acls => [qr/^(di\.see\.properties)$/],
		  qvd_object => 'DI_Property_List'},

di_create_property_list => { type_of_action => 'create',
		 admin4method => 'create',
		 acls => [qr/^di\.update\.properties-create$/],
		 qvd_object => 'DI_Property_List'},

di_delete_property_list => { type_of_action => 'delete',
		 admin4method => 'delete',
		 acls => [qr/^di\.update\.properties-delete$/],
		 qvd_object => 'DI_Property_List'},

tag_tiny_list => { type_of_action => 'tiny',
		   admin4method => 'select',
		   qvd_object => 'DI_Tag'},

tag_get_list => { type_of_action => 'list',
		   admin4method => 'select',
		   qvd_object => 'DI_Tag'},

admin_get_list => { type_of_action => 'list',
		    admin4method => 'select',
		    acls => [qr/^administrator\.see-main\./],
		    qvd_object => 'Administrator' },

admin_tiny_list => { type_of_action => 'tiny',
		    admin4method => 'select',
		    acls => [qr/^log\.filter\.administrator/],
		    qvd_object => 'Administrator' },

admin_get_details => { type_of_action => 'details',
		       admin4method => 'select',
		       acls => [qr/^administrator\.see-details\./],
		       qvd_object => 'Administrator'},

admin_all_ids => { type_of_action => 'all_ids',
		   admin4method => 'select',
		   acls => [qr/^administrator\.[^.]+-massive\.|administrator\.see-details\./],
		   qvd_object => 'Administrator'},

admin_create => { type_of_action => 'create',
		  admin4method => 'create',
		  acls => [qr/^administrator\.create\./],
		  qvd_object => 'Administrator'},

admin_update => { type_of_action => 'update',
		  admin4method => 'update',
#		  acls => [qr/^administrator\.update\./],
		  qvd_object => 'Administrator'},

myadmin_update => { type_of_action => 'update',
		  admin4method => 'update',
		  qvd_object => 'Administrator'},

admin_delete => { type_of_action => 'delete',
		  admin4method => 'delete',
		  acls => [qr/^administrator\.delete\./],
		  qvd_object => 'Administrator'},

tenant_tiny_list => { type_of_action => 'tiny',
		      admin4method => 'select',
		      qvd_object => 'Tenant'},

tenant_get_list => { type_of_action => 'list',
		     admin4method => 'select',
		     acls => [qr/^tenant\.see-main\./],
		     qvd_object => 'Tenant'},

tenant_get_details => { type_of_action => 'details',
			admin4method => 'select',
			acls => [qr/^(config\.wat|tenant\.see-details)\./],
			qvd_object => 'Tenant'},

tenant_all_ids => { type_of_action => 'all_ids',
		    admin4method => 'select',
		    acls => [qr/^tenant\.[^.]+-massive\.|tenant\.see-main\./],
		    qvd_object => 'Tenant'},

tenant_update => { type_of_action => 'update',
		   admin4method => 'update',
		   acls => [qr/^(config\.wat|tenant\.update)\./],
		   qvd_object => 'Tenant'},

mytenant_update => { type_of_action => 'update',
		     admin4method => 'update',
		     qvd_object => 'Tenant'},

tenant_create => { type_of_action => 'create',
		   admin4method => 'create',
		   acls => [qr/^tenant\.create\./],
		   qvd_object => 'Tenant'},

tenant_delete => { type_of_action => 'delete',
		   admin4method => 'delete',
		   acls => [qr/^tenant\.delete\./],
		   qvd_object => 'Tenant'},

role_tiny_list => { type_of_action => 'tiny',
		    admin4method => 'select',
		   acls => [qr/^(administrator\.see\.|role\.see\.inherited-)roles$/],
		    qvd_object => 'Role'},

role_get_list => { type_of_action => 'list',
		   admin4method => 'select',
		   acls => [qr/^role\.see-main\./],
		   qvd_object => 'Role'},

role_get_details => { type_of_action => 'details',
		      admin4method => 'select',
		   acls => [qr/^role\.see-details\./],
		      qvd_object => 'Role'},

role_all_ids => { type_of_action => 'all_ids',
		  admin4method => 'select',
		  acls => [qr/^role\.[^.]+-massive\.|role\.see-main\./],
		  qvd_object => 'Role'},

acl_tiny_list => { type_of_action => 'tiny',
		   admin4method => 'select',
		   acls => [qr/^(role|administrator)\.see\.acl-list$/],
		   qvd_object => 'ACL'},


acl_get_list => { type_of_action => 'list',
		  admin4method => 'select',
		  acls => [qr/^(role|administrator)\.see\.acl-list$/],
		  qvd_object => 'Operative_Acls_In_Administrator',
		  admin4method => 'acl_get_list'},

get_acls_in_roles => { type_of_action => 'list',
		       qvd_object => 'Operative_Acls_In_Role',
		       acls => [qr/^administrator\.see\.acl-list$/],
		       admin4method => 'get_acls_in_roles'},

get_acls_in_admins => { type_of_action => 'list',
		       qvd_object => 'Operative_Acls_In_Administrator',
			acls => [qr/^administrator\.see\.acl-list$/],
		      admin4method => 'get_acls_in_admins'},


number_of_acls_in_role => { type_of_action =>  'ad_hoc',
			    acls => [qr/^administrator\.see\.acl-list$/],
			    admin4method => 'get_number_of_acls_in_role'},

number_of_acls_in_admin => { type_of_action =>  'ad_hoc',
			     acls => [qr/^administrator\.see\.acl-list$/],
			     admin4method => 'get_number_of_acls_in_admin'},

role_update => { type_of_action => 'update',
		 admin4method => 'update',
		 acls => [qr/^role\.update\./],
		 qvd_object => 'Role'},

role_create => { type_of_action => 'create',
		 admin4method => 'create',
		 acls => [qr/^role\.create\./],
		 qvd_object => 'Role'},

role_delete => { type_of_action => 'delete',
		 admin4method => 'delete',
		 acls => [qr/^role\.delete\./],
		 qvd_object => 'Role'},

tenant_view_get_list => { type_of_action => 'list',
			  admin4method => 'tenant_view_get_list',
			  qvd_object => 'Operative_Views_In_Tenant',
			  acls => [qr/^views\.see-main\./]},

tenant_view_set => { type_of_action => 'create_or_update',
		     admin4method => 'create_or_update',
		     acls => [qr/^views\.update\./],
		     qvd_object => 'Tenant_Views_Setup'},

tenant_view_reset => { type_of_action => 'delete',
			admin4method => 'delete',
			acls => [qr/^views\.update\./],
		       qvd_object => 'Tenant_Views_Setup'},

admin_view_set => { type_of_action => 'create_or_update',
		    admin4method => 'create_or_update',
		    acls => [],
		    qvd_object => 'Administrator_Views_Setup'},

admin_view_reset => { type_of_action => 'delete',
		       admin4method => 'delete',
		       acls => [],
		       qvd_object => 'Administrator_Views_Setup'},

current_admin_setup => {type_of_action => 'ad_hoc',
		       admin4method => 'current_admin_setup'},

qvd_objects_statistics => { type_of_action =>  'multiple',
			    channels => [qw(vm_created_or_removed vm_blocked_or_unblocked vm_state_changed vm_expiration_date_changed
                                            host_created_or_removed host_blocked_or_unblocked host_state_changed
                                            user_created_or_removed user_blocked_or_unblocked user_state_changed
                                            osf_created_or_removed osf_blocked_or_unblocked
                                            di_created_or_removed di_blocked_or_unblocked)],
			    admin4methods => { users_count => { acls => [qr/^user\.stats/] },
					       blocked_users_count => { acls => [qr/^user\.stats\.blocked$/]},
					       connected_users_count => { acls => [qr/^user\.stats\.connected-users$/]},
					       vms_count => { acls => [qr/^vm\.stats/] },
					       blocked_vms_count => { acls => [qr/^vm\.stats\.blocked$/] },
					       running_vms_count => { acls => [qr/^vm\.stats\.running-vms$/] },
					       hosts_count => { acls => [qr/^host\.stats/] },
					       blocked_hosts_count => { acls => [qr/^host\.stats\.blocked$/] },
					       running_hosts_count => { acls => [qr/^host\.stats\.running-hosts$/] },
					       osfs_count => { acls => [qr/^osf\.stats/] },
					       dis_count => { acls => [qr/^di\.stats/] },
					       blocked_dis_count => { acls => [qr/^di\.stats\.blocked$/] },
					       vms_with_expiration_date => { acls => [qr/^vm\.stats\.close-to-expire$/] },
					       top_populated_hosts => { acls => [qr/^host\.stats\.top-hosts-most-vms$/] } },
			    acls => [qr/^[^.]+\.stats\./]},

property_get_list => {type_of_action => 'list',
		  admin4method => 'select',
		  qvd_object => 'Property_List'},

property_create => { type_of_action => 'create',
		 admin4method => 'create',
		 qvd_object => 'Property_List'},

property_update => { type_of_action => 'update',
		 admin4method => 'update',
		 qvd_object => 'Property_List'},

property_delete => { type_of_action => 'delete',
		 admin4method => 'delete',
		 qvd_object => 'Property_List'},
};


sub BUILD
{
    my $self = shift;
    my $name = $self->name;

# If the name of the action is not available, the constructor
# will complaint and die

    QVD::Admin4::Exception->throw(code => 4110) if
	ref($name) || (not defined $name) || $name eq '';

    QVD::Admin4::Exception->throw(code => 4100) 
	unless $self->available;
}


sub available
{
    my $self = shift;

    exists $ACTIONS->{$self->name} ? 
	return 1 : 
	return 0;
}

sub channels
{
    my $self = shift;
    $ACTIONS->{$self->name}->{'channels'} || [];
}

sub type
{
    my $self = shift;
    $ACTIONS->{$self->name}->{type_of_action};
}

sub qvd_object
{
    my $self = shift;
    $ACTIONS->{$self->name}->{qvd_object};
}

# Returns the method of QVD::Admin4 that must be executed
# in order to execute the action. This method will be executed from
# another method in QVD::Admin4::REST. The name of that other method 
# will be provided by the method 'restmethod' of this class

sub admin4method
{
    my $self = shift;
    $ACTIONS->{$self->name}->{admin4method};
}

# Returns the methods of QVD::Admin4 that must be
# executed in order to execute a multiple action

sub admin4methods
{
    my $self = shift;
    my $methods = $ACTIONS->{$self->name}->{admin4methods} // {};
    return keys %$methods;
}

sub acls
{
    my $self = shift;
    my $acls = eval { $ACTIONS->{$self->name}->{acls} } // [];
    @$acls;
}

# returns the acls needed to execute one of the actions
# nested in a multiple action

sub acls_for_nested_action
{
    my ($self,$na) = @_;
    my $acls = eval { $ACTIONS->{$self->name}->{admin4methods}->{$na}->{acls} } // [];
    @$acls;
}

# Returns the method of QVD::Admin4::REST that must be executed
# in order to execute the action.
# It depends of the type_of_action value.
# This method is the method from which the method provided by 
# 'admin4method' will be executed

sub restmethod
{
    my $self = shift;

    return 'process_multiple_query' if 
	$ACTIONS->{$self->name}->{type_of_action} eq 'multiple';
    return 'process_ad_hoc_query' if 
	$ACTIONS->{$self->name}->{type_of_action} eq 'ad_hoc';
    return 'process_standard_query';
}

sub available_for_admin
{
    my ($self,$admin) = @_;
    
    $admin->re_is_allowed_to($self->acls);
}

# Checks if the admin is allowed to execute the actions of a multiple action

sub available_nested_action_for_admin
{
    my ($self,$admin,$na) = @_;
    $admin->re_is_allowed_to($self->acls_for_nested_action($na));
}

1;
