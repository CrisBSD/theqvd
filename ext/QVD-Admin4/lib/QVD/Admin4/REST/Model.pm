package QVD::Admin4::REST::Model;
use strict;
use warnings;
use Moo;
use QVD::Config::Network qw(nettop_n netstart_n net_aton net_ntoa);
use QVD::Config;
use File::Basename qw(basename);
use QVD::Admin4::DBConfigProvider;
use Clone qw(clone);

has 'current_qvd_administrator', is => 'ro', isa => 
    sub { die "Invalid type for attribute current_qvd_administrator" 
	      unless ref(+shift) eq 'QVD::DB::Result::Administrator'; }, required => 1;
has 'qvd_object', is => 'ro', isa => sub {die "Invalid type for attribute qvd_object" 
					      if ref(+shift);}, required => 1;
has 'type_of_action', is => 'ro', isa => sub {die "Invalid type for attribute type_of_action" 
						  if ref(+shift);}, required => 1;

has 'model_info', is => 'ro', isa => sub {die "Invalid type for attribute model_info" 
					      unless ref(+shift) eq 'HASH';}, 
    default => sub {{};};

my $DBConfigProvider;

my $RELATED_VIEWS_IN_DB = 
{   
    list => { User => [qw(User_View)],
	      VM => [qw(VM_View)],
	      Host => [qw(Host_View)],
	      OSF => [qw(OSF_View)],
	      DI => [qw(DI_View)] },

    details => { User => [qw(User_View)],
		 VM => [qw(VM_View)],
		 Host => [qw(Host_View)],
		 OSF => [qw(OSF_View)],
		 DI => [qw(DI_View)] },		 
};


my $RRRRR = {};

my $ACLS_FOR_FILTERS = 
{
    VM => { properties => [qr/^vm\.filter\.properties$/], 
	    name => [qr/^vm\.filter\.name$/],
	    user_id => [qr/^vm\.filter\.user|user\.see\.vm-list$/],
	    user_name => [qr/^vm\.filter\.user$/],
	    osf_id => [qr/^vm\.filter\.osf|osf\.see\.vm-list$/],
	    osf_name => [qr/^vm\.filter\.osf$/],
	    di_id => [qr/^vm\.filter\.di|di\.see\.vm-list$/],
	    state => [qr/^vm\.filter\.state$/],
	    host_id => [qr/^vm\.filter\.host|host\.see\.vm-list$/],
	    host_name => [qr/^vm\.filter\.host$/]},

    User => { properties => [qr/^user\.filter\.properties$/], 
	      name => [qr/^user\.filter\.name$/]},

    Host => { properties => [qr/^host\.filter\.properties$/],
	      name => [qr/^host\.filter\.name$/],
	      vm_id => [qr/^host\.filter\.vm$/]},

    DI => { properties => [qr/^di\.filter\.properties$/],
	    disk_image => [qr/^di\.filter\.disk-image$/],
	    osf_id => [qr/^di\.filter\.osf|osf\.see\.di-list$/],
	    osf_name => [qr/^di\.filter\.osf$/]},

    OSF => { properties => [qr/^osf\.filter\.properties$/],
	     name => [qr/^osf\.filter\.name$/],
	     vm_id => [qr/^osf\.filter\.vm$/],
	     di_id => [qr/^osf\.filter\.di$/]},

    Administrator => { name => [qr/^administrator\.filter\.name$/] },	    

    Role => { name => [qr/^role\.filter\.name$/] },	    

    Tenant => { name => [qr/^tenant\.filter\.name$/] }
};

my $ACLS_FOR_FIELDS = 
{
    OSF => { creation_admin => [qr/^osf\.see\.created-by$/],
	     creation_date => [qr/^osf\.see\.creation-date$/],
	     overlay => [qr/^osf\.see\.overlay$/],
	     user_storage => [qr/^osf\.see\.user-storage$/],
	     memory => [qr/^osf\.see\.memory$/],
	     number_of_vms => [qr/^osf\.see\.vms-info$/],
	     number_of_dis => [qr/^osf\.see\.dis-info$/],
	     properties => [qr/^osf\.see\.properties$/] },

    Role => { roles => [qr/^role\.see\.acl-list$/, 
			qr/^role\.see\.acl-list-roles$/, 
			qr/^role\.see\.inherited-roles$/],
	      acls => [qr/^role\.see\.acl-list$/],
	      number_of_acls => [qr/^role\.see\.acl-list$/] },

    DI => { creation_admin => [qr/^di\.see\.created-by$/],
	    creation_date => [qr/^di\.see\.creation-date$/],
	    version => [qr/^di\.see\.version$/],
	    osf_id => [qr/^di\.see\.osf$/],
	    osf_name => [qr/^di\.see\.osf$/],
	    blocked => [qr/^di\.see\.block$/],
	    tags => [qr/^(di\.see\.|[^.]+\.see\.di-list-)(tags|default|head)$/],
	    properties => [qr/^di\.see\.properties$/]  },

    VM => { user_id => [qr/^vm\.see\.user$/],
	    user_name => [qr/^vm\.see\.user$/],
	    osf_id => [qr/^vm\.see\.osf$/],
	    osf_name => [qr/^vm\.see\.osf$/],
	    di_tag => [qr/^vm\.see\.di-tag$/],
	    blocked => [qr/^(vm\.see\.|[^.]+\.see\.vm-list-)block$/],
	    expiration_soft => [qr/^(vm\.see\.|[^.]+\.see\.vm-list-)expiration$/],
	    expiration_hard => [qr/^(vm\.see\.|[^.]+\.see\.vm-list-)expiration$/],
	    state => [qr/^(vm\.see\.|[^.]+\.see\.vm-list-)state$/],
	    host_id => [qr/^vm\.see\.host$/],
	    host_name => [qr/^vm\.see\.host$/],
	    di_id => [qr/^vm\.see\.di$/],
	    user_state => [qr/^vm\.see\.user-state$/],
	    ip => [qr/^vm\.see\.ip$/],
	    mac => [qr/^vm\.see\.mac$/],
	    next_boot_ip => [qr/^vm\.see\.next-boot-ip$/],
	    ssh_port => [qr/^vm\.see\.port-ssh$/],
	    vnc_port => [qr/^vm\.see\.port-vnc$/],
	    serial_port => [qr/^vm\.see\.port-serial$/], 
	    creation_admin => [qr/^vm\.see\.created-by$/],
	    creation_date => [qr/^vm\.see\.creation-date$/],
	    di_version => [qr/^vm\.see\.di-version$/],
	    di_name => [qr/^vm\.see\.di$/],
	    di_id => [qr/^vm\.see\.di$/],
	    properties => [qr/^vm\.see\.properties$/] },
 
   Administrator => { roles => [qr/^administrator\.see\.roles$/],
		       id => [qr/^administrator\.see\.id$/] },

    User => { id => [qr/^user\.see\.id$/],
	      blocked => [qr/^user\.see\.block$/],
	      creation_admin => [qr/^user\.see\.created-by$/],
	      creation_date => [qr/^user\.see\.creation-date$/],
	      number_of_vms => [qr/^user\.see\.vms-info$/],
	      number_of_vms_connected => [qr/^user\.see\.vm-list-state$/],
	      properties => [qr/^user\.see\.properties$/] },

    Host => { id => [qr/^host\.see\.id$/],
	      address => [qr/^host\.see\.address$/],
	      blocked => [qr/^host\.see\.block$/],
	      state => [qr/^host\.see\.state$/],
	      creation_admin => [qr/^host\.see\.created-by$/],
	      creation_date => [qr/^host\.see\.creation-date$/],
	      number_of_vms_connected => [qr/^host\.see\.vms-info$/],
	      properties => [qr/^host\.see\.properties$/] },
};

my $ACLS_FOR_ARGUMENTS_IN_UPDATE = 
{ 
    User => { password => [qr/^user\.update\.password$/],
	      blocked => [qr/^user\.update\.block$/],
	      __properties_changes_set => [qr/^user\.update\.properties-(cre|upd)ate$/],
	      __properties_changes_delete => [qr/^user\.update\.properties-delete$/]},

    VM => { '***start***' => [qr/^vm\.update\.state$/], 
	    '***stop***' => [qr/^(vm\.update\.state|host\.update\.stop-vms)$/],
	    '***disconnect***' => [qr/^vm\.update\.disconnect-user$/], 
	    name => [qr/^vm\.update\.name$/],
	    blocked => [qr/^vm\.update\.block$/],
	    expiration_soft => [qr/^vm\.update\.expiration$/],
	    expiration_hard => [qr/^vm\.update\.expiration$/],
	    di_tag => [qr/^vm\.update\.di-tag$/],
	    __properties_changes__set => [qr/^vm\.update\.properties-(cre|upd)ate$/],
	    __properties_changes__delete => [qr/^vm\.update\.properties-delete$/] },

    Host => { name => [qr/^host\.update\.name$/],
	      address => [qr/^host\.update\.address$/],
	      blocked => [qr/^host\.update\.block$/],
	      __properties_changes__set => [qr/^host\.update\.properties-(cre|upd)ate$/],
	      __properties_changes__delete => [qr/^host\.update\.properties-delete$/] },

    OSF => { name => [qr/^osf\.update\.name$/],
	     memory => [qr/^osf\.update\.memory$/],
	     user_storage => [qr/^osf\.update\.user-storage$/],
	     __properties_changes__set => [qr/^osf\.update\.properties-(cre|upd)ate$/],
	     __properties_changes__delete => [qr/^osf\.update\.properties-delete$/] },

    DI => { blocked => [qr/^di\.update\.block$/],
	    __properties_changes__set => [qr/^di\.update\.properties-(cre|upd)ate$/],
	    __properties_changes__delete => [qr/^di\.update\.properties-delete$/],
	    __tags_changes__create => [qr/^(di\.update\.(tags|defaults)|osf\.see\.di-list-default-update)$/],
	    __tags_changes__delete => [qr/^(di\.update\.(tags|defaults)|osf\.see\.di-list-default-update)$/]},

    Role => { name => [qr/^role\.update\.name$/],
	      __acls_changes__assign_acls => [qr/^role\.update\.assign-acl$/],
	      __acls_changes__unassign_acls => [qr/^role\.update\.assign-acl$/],
	      __roles_changes__assign_roles => [qr/^role\.update\.assign-role$/],
	      __roles_changes__unassign_roles => [qr/^role\.update\.assign-role$/] },

    Administrator => { password => [qr/^administrator\.update\.password$/],
		       __roles_changes__assign_roles => [qr/^administrator\.update\.assign-role$/],
		       __roles_changes__unassign_roles => [qr/^administrator\.update\.assign-role$/] },

    Tenant_Views_Setup => { visible => [qr/^views\.update\.columns$/] },  
    Administrator_Views_Setup => { visible => [qr/^views\.update\.columns$/] }

};


my $ACLS_FOR_ARGUMENTS_IN_MASSIVE_UPDATE = 
{ 
    User => { '***delete***' => [qr/^user\.delete-massive\.$/], # MAYBE A NEW VARIABLE?
	      blocked => [qr/^user\.update-massive\.block$/],
	      __properties_changes__set => [qr/^user\.update-massive\.properties-(cre|upd)ate$/],
	      __properties_changes__delete => [qr/^user\.update-massive\.properties-delete$/]},

    VM => { '***delete***' => [qr/^vm\.delete-massive\.$/],
	    '***start***' => [qr/^vm\.update-massive\.state$/], 
	    '***stop***' => [qr/^(vm\.update-massive\.state|host\.update-massive\.stop-vms)$/],
	    '***disconnect***' => [qr/^vm\.update-massive\.disconnect-user$/], 
	    blocked => [qr/^vm\.update-massive\.block$/],
	    expiration_soft => [qr/^vm\.update-massive\.expiration$/],
	    expiration_hard => [qr/^vm\.update-massive\.expiration$/],
	    di_tag => [qr/^vm\.update-massive\.di-tag$/],
	    __properties_changes__set => [qr/^vm\.update-massive\.properties-(cre|upd)ate$/],
	    __properties_changes__delete => [qr/^vm\.update-massive\.properties-delete$/] },

    Host => { '***delete***' => [qr/^host\.delete-massive\.$/],
	      blocked => [qr/^host\.update-massive\.block$/],
	      __properties_changes__set => [qr/^host\.update-massive\.properties-(cre|upd)ate$/],
	      __properties_changes__delete => [qr/^host\.update-massive\.properties-delete$/] },
	
    OSF => { '***delete***' => [qr/^osf\.delete-massive\.$/],
	     memory => [qr/^osf\.update-massive\.memory$/],
	     user_storage => [qr/^osf\.update-massive\.user-storage$/],
	     __properties_changes__set => [qr/^osf\.update-massive\.properties-(cre|upd)ate$/],
	     __properties_changes__delete => [qr/^osf\.update-massive\.properties-delete$/] },
	
    DI => { '***delete***' => [qr/^di\.delete-massive\.$/],
	    blocked => [qr/^di\.update-massive\.block$/],
	    __properties_changes__set => [qr/^di\.update-massive\.properties-(cre|upd)ate$/],
	    __properties_changes__delete => [qr/^di\.update-massive\.properties-delete$/],
	    __tags_changes__create => [qr/^di\.update-massive\.tags$/],
	    __tags_changes__delete => [qr/^di\.update-massive\.tags-delete$/]},
	
    Tenant => { '***delete***' => [qr/^tenant\.delete-massive\.$/]},

    Role => { '***delete***' => [qr/^role\.delete-massive\.$/] },

    Administrator => { '***delete***' => [qr/^administrator\.delete-massive\.$/]}

};


my $ACLS_FOR_ARGUMENTS_IN_CREATION = 
{ 
    User => { __properties__ => [qr/^user\.create\.properties$/]},
    
    VM => { di_tag => [qr/^vm\.create\.di-tag$/],
	    __properties__ => [qr/^vm\.create\.properties$/] },
    
    Host => {__properties__ => [qr/^host\.create\.properties$/] },

    OSF => { memory => [qr/^osf\.create\.memory$/],
	     user_storage => [qr/^osf\.create\.user-storage$/],
	     __properties__ => [qr/^osf\.create\.properties$/]},

    DI => { version => [qr/^di\.create\.version$/],
	    __properties__ => [qr/^di\.create\.properties$/],
	    __tags__ => [qr/^di\.create\.(tags|default)$/]}

};

my $AVAILABLE_FILTERS = 
{ 
    list => { default => [],

	      Config => [qw(key value)],
	      
	      VM => [qw(storage id name user_id user_name osf_id osf_name di_tag blocked 
                        expiration_soft expiration_hard state host_id host_name di_id 
                        user_state ip next_boot_ip ssh_port vnc_port serial_port tenant_id tenant_name 
                        creation_admin creation_date )],

	      DI_Tag => [qw(osf_id name id tenant_id tenant_name)],

	      User => [qw(id name blocked creation_admin creation_date tenant_id tenant_name )],

	      Host => [qw(id name address blocked frontend backend state vm_id creation_admin creation_date )],

	      DI => [qw(id disk_image version osf_id osf_name tenant_id blocked tenant_name tag)],

	      OSF => [qw(id name overlay user_storage memory vm_id di_id tenant_id tenant_name )],

	      ACL => [qw(id name role_id admin_id)],

	      Tenant => [qw(id name)],

	      Role => [qw(name id fixed internal)],

	      Administrator => [qw(name tenant_id tenant_name id )],

	      Tenant_Views_Setup => [qw(id tenant_id tenant_name field visible view_type device_type qvd_object property)],

	      Administrator_Views_Setup => [qw(id admin_id admin_name field tenant_id tenant_name visible 
                                               view_type device_type qvd_object property)]},

    all_ids => { default => [],

		 Config => [qw(key value)],

		 VM => [qw(storage id name user_id user_name osf_id osf_name di_tag blocked expiration_soft 
                           expiration_hard state host_id host_name  di_id user_state ip next_boot_ip ssh_port 
                           vnc_port serial_port tenant_id tenant_name creation_admin creation_date )],

		 DI_Tag => [qw(osf_id name id tenant_id tenant_name)],

		 User => [qw(id name blocked creation_admin creation_date tenant_id tenant_name )],

		 Host => [qw(id name address blocked frontend backend state vm_id creation_admin creation_date )],

		 DI => [qw(id disk_image version osf_id osf_name tenant_id blocked tenant_name tag)],

		 OSF => [qw(id name overlay user_storage memory vm_id di_id tenant_id tenant_name )],

		 ACL => [qw(id name role_id admin_id )],

		 Role => [qw(name id fixed internal)],

		 Tenant => [qw(id name)],

		 Administrator => [qw(name tenant_id tenant_name role_id acl_id id role_name acl_name )],

		 Tenant_Views_Setup => [qw(id tenant_id tenant_name field visible view_type device_type qvd_object property)],

		 Administrator_Views_Setup => [qw(id tenant_id tenant_name field admin_id admin_name visible view_type 
                                                  device_type qvd_object property)]},

    details => { Config => [qw(key value)], default => [qw(id tenant_id)], Host => [qw(id)], Role => [qw(id)], ACL => [qw(id)], Tenant => [qw(id)] },
		
    tiny => { default => [qw(tenant_id)], Host => [qw()], Role => [qw(internal fixed)], ACL => [qw(name)], Tenant => [qw()], DI_Tag => [qw(tenant_id osf_id)]},

    delete => { default => [qw(id tenant_id)], Host => [qw(id)], ACL => [qw(id)], Role => [qw(id)], Tenant => [qw(id)], Config => [qw(key)]},

    update => { default => [qw(id tenant_id)], Host => [qw(id)], ACL => [qw(id)], Role => [qw(id)], Tenant => [qw(id)], Config => [qw(key)]},

    state => { default => [qw(id tenant_id)], Host => [qw(id)], ACL => [qw(id)], Role => [qw(id)], Tenant => [qw(id)]},
};

my $AVAILABLE_FIELDS = 
{ 
    list => { default => [],

	      Config => [qw(key value)],

	      OSF => [qw(id name overlay user_storage memory  number_of_vms number_of_dis properties )],

	      Role => [qw(name roles acls id number_of_acls fixed internal)],

	      DI => [qw(id disk_image version osf_id osf_name blocked tags  properties )],

	      VM => [qw(storage id name user_id user_name osf_id osf_name di_tag blocked expiration_soft expiration_hard 
                        state host_id host_name  di_id user_state ip mac next_boot_ip ssh_port vnc_port serial_port 
                        creation_admin creation_date di_version di_name di_id properties )],

	      ACL => [qw(id name)],

	      Administrator => [qw(name roles id )],

	      Tenant => [qw(id name)],
				   
	      User => [qw(id name  blocked creation_admin creation_date number_of_vms number_of_vms_connected  properties )],

	      Host => [qw(id name address blocked frontend backend state  load creation_admin creation_date number_of_vms_connected properties )],

	      DI_Tag => [qw(osf_id name id )],

	      Tenant_Views_Setup => [qw(id tenant_id tenant_name field visible view_type device_type qvd_object property)],

	      Administrator_Views_Setup => [qw(id tenant_id tenant_name admin_id admin_name field visible view_type 
                                               device_type qvd_object property)] },

    details => { default => [],
		 
		 Config => [qw(key value)],

		 OSF => [qw(id name overlay user_storage memory  number_of_vms number_of_dis properties )],
		 
		 Role => [qw(name acls roles id number_of_acls fixed internal)],
		
		 DI => [qw(id disk_image version osf_id osf_name  blocked tags  properties )],
		
		 VM => [qw(storage id name user_id user_name osf_id osf_name di_tag blocked expiration_soft expiration_hard 
                           state host_id host_name  di_id user_state ip mac next_boot_ip ssh_port vnc_port serial_port 
                           creation_admin creation_date di_version di_name di_id properties )],

		 ACL => [qw(id name)],

		 Administrator => [qw(name roles id )],

		 Tenant => [qw(id name)],

		 User => [qw(id name  blocked creation_admin creation_date number_of_vms number_of_vms_connected  properties )],

		 Host => [qw(id name address blocked frontend backend state  load creation_admin creation_date 
                             number_of_vms_connected number_of_vms properties )],

		 DI_Tag => [qw(osf_id name id )],

		 Tenant_Views_Setup => [qw(id tenant_id tenant_name field visible view_type device_type qvd_object property)],

		 Administrator_Views_Setup => [qw(id admin_id admin_name tenant_id tenant_name field visible view_type 
                                                  device_type qvd_object property)] },

    tiny => { default => [qw(id name)],

	      DI => [qw(id disk_image)],

	      Tenant_Views_Setup => [qw(id)],

	      Administrator_Views_Setup => [qw(id)]},

    all_ids => { default => [qw(id)]},

    state => { User => [qw(number_of_vms_connected)],
	       
	       VM => [qw(state user_state)],
	       
	       Host => [qw(number_of_vms_connected)]},
    
    create => { 'default' => [qw(id)], Config => [qw(key)]}

};

my $MANDATORY_FILTERS = 
{ 
    list => { default => [qw(tenant_id)], Host => [qw()], ACL => [qw()], Role => [qw()], Tenant => [qw()], Config => [qw()]},

    details => { default => [qw(id tenant_id)], Host => [qw(id)], ACL => [qw(id)], Role => [qw(id)], Tenant => [qw(id)]}, 

    tiny => { default => [qw(tenant_id)], Host => [qw()], ACL => [qw()], Role => [qw()], Tenant => [qw()]},

    delete => { default => [qw(id tenant_id)], Host => [qw(id)], ACL => [qw(id)], Role => [qw(id)], Tenant => [qw(id)], Config => [qw(key)]},

    update=> { default => [qw(id tenant_id)], Host => [qw(id)], ACL => [qw(id)], Role => [qw(id)], Tenant => [qw(id)], Config => [qw(key)]}, 

    state => { default => [qw(id tenant_id)], Host => [qw(id)], ACL => [qw(id)], Role => [qw(id)], Tenant => [qw(id)]}, 

    all_ids => { default => [qw(tenant_id)], Host => [qw()], ACL => [qw()], Role => [qw()], Tenant => [qw()], Config => [qw()]}, 
};

my $SUBCHAIN_FILTERS = 
{ 
    list => { default => [qw(name)],
	      DI => [qw(disk_image)],
	      Administrator => [qw(name role_name acl_name)],
	      Role => [qw(name nested_role_name acl_name)]}
};

my $COMMODIN_FILTERS = 
{ 
tiny => { ACL => [qw(name)]},
list => {Config => [qw(key value)]}
};

my $DEFAULT_ORDER_CRITERIA = 
{ 
    tiny => { default =>  [qw(name)],
	      DI => [qw(disk_image)],
	      Tenant_Views_Setup => [qw(field)],
	      Administrator_Views_Setup => [qw(field)],
              Config => [qw(key)] }
};

my $AVAILABLE_NESTED_QUERIES = 
{ 
    create => { User => [qw(__properties__)],
		VM => [qw(__properties__)],
		Host => [qw(__properties__)],
		OSF => [qw(__properties__)],
		DI => [qw(__properties__ __tags__)],
		Tenant => [qw()],
		Role => [qw(__acls__ __roles__)],
		Administrator => [qw(__roles__)],
		Tenant_Views_Setup => [qw()],
		Administrator_Views_Setup => [qw()]},

    update => { User => [qw(__properties_changes__set __properties_changes__delete)],
		VM => [qw(__properties_changes__set __properties_changes__delete)],
		Host => [qw(__properties_changes__set __properties_changes__delete)],
		OSF => [qw(__properties_changes__set __properties_changes__delete)],
		DI => [qw(__properties_changes__set __properties_changes__delete 
                          __tags_changes__create __tags_changes__delete)],
	        Tenant => [qw()],
		Role => [qw(__acls_changes__assign_acls 
                            __acls_changes__unassign_acls
			    __roles_changes__assign_roles 
                            __roles_changes__unassign_roles)],
		Administrator => [qw(__roles_changes__assign_roles __roles_changes__unassign_roles)],
		Tenant_Views_Setup => [qw()],
		Administrator_Views_Setup => [qw()]}
};



my $NESTED_QUERIES_TO_ADMIN4_MAPPER = 
{ 
    User => { __properties__ => 'custom_properties_set',
	      __properties_changes__set => 'custom_properties_set',
	      __properties_changes__delete => 'custom_properties_del'},
  
    VM => { __properties__ => 'custom_properties_set',
	    __properties_changes__set => 'custom_properties_set',
	    __properties_changes__delete => 'custom_properties_del'},
    
    Host => { __properties__ => 'custom_properties_set',
	      __properties_changes__set => 'custom_properties_set',
	      __properties_changes__delete => 'custom_properties_del' },
  
    OSF => { __properties__ => 'custom_properties_set',
	     __properties_changes__set => 'custom_properties_set',
	     __properties_changes__delete => 'custom_properties_del'},
  
    DI => { __properties__ => 'custom_properties_set',
	    __tags__ => 'tags_create',
	    __properties_changes__set => 'custom_properties_set',
	    __properties_changes__delete => 'custom_properties_del', 
	    __tags_changes__create => 'tags_create',
	    __tags_changes__delete => 'tags_delete'},
    Tenant => {},

    Role => { __acls__ => 'add_acls_to_role',
	      __roles__ => 'add_roles_to_role',
	      __acls_changes__assign_acls  => 'add_acls_to_role',
	      __acls_changes__unassign_acls => 'del_acls_to_role',
	      __roles_changes__assign_roles => 'add_roles_to_role', 
	      __roles_changes__unassign_roles => 'del_roles_to_role'},

    Administrator => { __roles__ => 'add_roles_to_admin',
		       __roles_changes__assign_roles => 'add_roles_to_admin',
		       __roles_changes__unassign_roles => 'del_roles_to_admin' },
    Tenant_Views_Setup => {},
    Administrator_Views_Setup => {}
};

my $AVAILABLE_ARGUMENTS = { Config => [qw(value)],
			    User => [qw(name password blocked)],
                            VM => [qw(name ip blocked expiration_soft expiration_hard storage di_tag ***start*** ***stop*** ***disconnect***)],
                            Host => [qw(name address blocked)],
                            OSF => [qw(name memory user_storage overlay)],
                            DI => [qw(blocked disk_image)],
			    Tenant => [qw(name)],
			    Role => [qw(name)],
			    Administrator => [qw(name password)],
			    Tenant_Views_Setup => [qw(visible)],
			    Administrator_Views_Setup => [qw(visible)]};


my $MANDATORY_ARGUMENTS = { Config => [qw(key value)],
			    User => [qw(name password tenant_id blocked)],
			    VM => [qw(name user_id ip osf_id di_tag state user_state blocked)],
			    Host => [qw(name address frontend backend blocked state)],
			    OSF => [qw(name memory overlay user_storage tenant_id)],
                            DI => [qw(version disk_image osf_id blocked)],
			    Tenant => [qw(name)],
			    Role => [qw(name fixed internal)],
                            Administrator => [qw(name password tenant_id)],
			    Tenant_Views_Setup => [qw(tenant_id field visible view_type device_type qvd_object property)],
			    Administrator_Views_Setup => [qw(admin_id field visible view_type device_type qvd_object property)]}; 

my $DEFAULT_ARGUMENT_VALUES = 
{
    User => { blocked => 'false' },

    VM => { di_tag => 'default',
	    blocked => 'false',
	    user_state => 'disconnected',
	    state => 'stopped',
	    ip => \&get_free_ip},

    Host => { backend => 'true',
	      frontend => 'true',
	      blocked => 'false',
	      state => 'stopped'},

    OSF => { memory => \&get_default_memory,
	     overlay => \&get_default_overlay,
	     user_storage => 0 },

    DI => { blocked => 'false' },

    Role => { fixed => 'false', internal => 'false' },

    Tenant_Views_Setup => { visible => 0, property => 0 },

    Administrator_Views_Setup =>  { visible => 0, property => 0 }
};

my $FILTERS_TO_DBIX_FORMAT_MAPPER = 
{
    Config => {
	'key' => 'me.key',
	'value' => 'me.value'
    },

    ACL => {
	'id' => 'me.id',
	'name' => 'me.name',
	'role_id' => 'role.id',
	'admin_id' => 'admin.id',
    },

    DI_Tag => {
	'osf_id' => 'di.osf_id',
	'name' => 'me.tag',
	'tenant_id' => 'tenant.id',
	'tenant_name' => 'tenant.name',
	'id' => 'me.id',
    },
    
    Administrator => {
	'name' => 'me.name',
	'password' => 'me.password',
	'tenant_id' => 'me.tenant_id',
	'tenant_name' => 'tenant.name',
	'role_id' => 'role.id',
	'acl_id' => 'acl.id',
	'role_name' => 'role.name',
	'acl_name' => 'acl.name',
	'id' => 'me.id',
    },

    OSF => {
	'id' => 'me.id',
	'name' => 'me.name',
	'overlay' => 'me.use_overlay',
	'user_storage' => 'me.user_storage_size',
	'memory' => 'me.memory',
	'vm_id' => 'vms.id',
	'di_id' => 'dis.id',
	'tenant_id' => 'me.tenant_id',
	'tenant_name' => 'tenant.name',
    },

    Host => {
	'id' => 'me.id',
	'name' => 'me.name',
	'address' => 'me.address',
	'blocked' => 'runtime.blocked',
	'frontend' => 'me.frontend',
	'backend' => 'me.backend',
	'state' => 'runtime.state',
	'vm_id' => 'vms.vm_id',
	'creation_admin' => 'me.creation_admin',
	'creation_date' => 'me.creation_date',
    },

    DI => {
	'id' => 'me.id',
	'disk_image' => 'me.path',
	'version' => 'me.version',
	'osf_id' => 'me.osf_id',
	'osf_name' => 'osf.name',
	'tag' => 'tags.tag',
	'tenant_id' => 'osf.tenant_id',
	'blocked' => 'me.blocked',
	'tenant_name' => 'tenant.name',
    },
    User => {
	'id' => 'me.id',
	'name' => 'me.login',
	'password' => 'me.password',
	'blocked' => 'me.blocked',
	'creation_admin' => 'me.creation_admin',
	'creation_date' => 'me.creation_date',
	'tenant_id' => 'me.tenant_id',
	'tenant_name' => 'tenant.name',
    },

    VM => {
	'storage' => 'me.storage',
	'id' => 'me.id',
	'name' => 'me.name',
	'user_id' => 'me.user_id',
	'user_name' => 'user.login',
	'osf_id' => 'me.osf_id',
	'osf_name' => 'osf.name',
	'di_tag' => 'me.di_tag',
	'blocked' => 'vm_runtime.blocked',
	'expiration_soft' => 'vm_runtime.vm_expiration_soft',
	'expiration_hard' => 'vm_runtime.vm_expiration_hard',
	'state' => 'vm_runtime.vm_state',
	'host_id' => 'vm_runtime.host_id',
	'host_name' => 'host.name',
	'di_id' => 'di.id',
	'user_state' => 'vm_runtime.user_state',
	'ip' => 'me.ip',
	'next_boot_ip' => 'vm_runtime.vm_address',
	'ssh_port' => 'vm_runtime.vm_ssh_port',
	'vnc_port' => 'vm_runtime.vm_vnc_port',
	'serial_port' => 'vm_runtime.vm_serial_port',
	'tenant_id' => 'user.tenant_id',
	'tenant_name' => 'tenant.name',
	'creation_admin' => 'me.creation_admin',
	'creation_date' => 'me.creation_date',
    },

    Role => {
	'name' => 'me.name',
	'fixed' => 'me.fixed',
	'internal' => 'me.internal',
	'id' => 'me.id',
    },

    Tenant => {
	'name' => 'me.name',
	'id' => 'me.id'
    },
    
    Tenant_Views_Setup => { 	
	'id' => 'me.id', 
	'tenant_id' => 'me.tenant_id', 
	'field' => 'me.field', 
	'tenant_name' => 'tenant.name', 
	'visible' => 'me.visible',
	'view_type' => 'me.view_type',
	'device_type' => 'me.device_type',
	'qvd_object' => 'me.qvd_object',
	'property' => 'me.property'
    },

    Administrator_Views_Setup =>  {
	'id' => 'me.id',  
	'tenant_id' => 'tenant.id', 
	'tenant_name' => 'tenant.name', 
	'admin_id' => 'me.administrator_id', 
	'field' => 'me.field', 
	'admin_name' => 'administrator.name', 
	'visible' => 'me.visible',
	'view_type' => 'me.view_type',
	'device_type' => 'me.device_type',
	'qvd_object' => 'me.qvd_object',
	'property' => 'me.property' 
 }

};

my $ARGUMENTS_TO_DBIX_FORMAT_MAPPER = 
    $FILTERS_TO_DBIX_FORMAT_MAPPER;

my $ORDER_CRITERIA_TO_DBIX_FORMAT_MAPPER = 
    $FILTERS_TO_DBIX_FORMAT_MAPPER;

my $FIELDS_TO_DBIX_FORMAT_MAPPER = 
{
    Config => {
	'key' => 'me.key',
	'value' => 'me.value'
    },

    ACL => {
	'id' => 'me.id',
	'name' => 'me.name',
    },

    Host => {
	'id' => 'me.id',
	'name' => 'me.name',
	'address' => 'me.address',
	'blocked' => 'runtime.blocked',
	'frontend' => 'me.frontend',
	'backend' => 'me.backend',
	'state' => 'runtime.state',
	'load' => 'me.load',
	'creation_admin' => 'me.creation_admin',
	'creation_date' => 'me.creation_date',
	'number_of_vms_connected' => 'view.number_of_vms_connected',
	'properties' => 'view.properties',
    },

    Role => {
	'name' => 'me.name',
	'fixed' => 'me.fixed',
	'internal' => 'me.internal',
	'acls' => 'me.get_positive_and_negative_acls_info',
	'roles' => 'me.get_roles_with_its_acls_info',
	'id' => 'me.id',
	'number_of_acls' => 'me.number_of_acls'
    },

    User => {
	'id' => 'me.id',
	'name' => 'me.login',
	'password' => 'me.password',
	'blocked' => 'me.blocked',
	'creation_admin' => 'me.creation_admin',
	'creation_date' => 'me.creation_date',
	'number_of_vms' => 'view.number_of_vms',
	'number_of_vms_connected' => 'view.number_of_vms_connected',
	'tenant_id' => 'me.tenant_id',
	'tenant_name' => 'tenant.name',
	'properties' => 'view.properties',
    },

    DI_Tag => {
	'osf_id' => 'di.osf_id',
	'tenant_id' => 'me.tenant_id',
	'tenant_name' => 'me.tenant_name',
	'name' => 'me.tag',
	'id' => 'me.id',
    },

    OSF => {
	'id' => 'me.id',
	'name' => 'me.name',
	'overlay' => 'me.use_overlay',
	'user_storage' => 'me.user_storage_size',
	'memory' => 'me.memory',
	'tenant_id' => 'me.tenant_id',
	'tenant_name' => 'tenant.name',
	'number_of_vms' => 'view.number_of_vms',
	'number_of_dis' => 'view.number_of_dis',
	'properties' => 'view.properties',
    },

    VM => {
	'storage' => 'me.storage',
	'id' => 'me.id',
	'name' => 'me.name',
	'user_id' => 'me.user_id',
	'user_name' => 'user.login',
	'osf_id' => 'me.osf_id',
	'osf_name' => 'osf.name',
	'di_tag' => 'me.di_tag',
	'blocked' => 'vm_runtime.blocked',
	'expiration_soft' => 'vm_runtime.vm_expiration_soft',
	'expiration_hard' => 'vm_runtime.vm_expiration_hard',
	'state' => 'vm_runtime.vm_state',
	'host_id' => 'vm_runtime.host_id',
	'host_name' => 'me.host_name',
	'di_id' => 'di.id',
	'user_state' => 'vm_runtime.user_state',
	'ip' => 'me.ip',
	'mac' => 'me.vm_mac',
	'next_boot_ip' => 'vm_runtime.vm_address',
	'ssh_port' => 'vm_runtime.vm_ssh_port',
	'vnc_port' => 'vm_runtime.vm_vnc_port',
	'serial_port' => 'vm_runtime.vm_serial_port',
	'tenant_id' => 'user.tenant_id',
	'tenant_name' => 'me.tenant_name',
	'creation_admin' => 'me.creation_admin',
	'creation_date' => 'me.creation_date',
	'di_version' => 'me.di_version',
	'di_name' => 'me.di_name',
	'di_id' => 'me.di_id',
	'properties' => 'view.properties',
    },

    DI => {
	'id' => 'me.id',
	'disk_image' => 'me.path',
	'version' => 'me.version',
	'osf_id' => 'me.osf_id',
	'osf_name' => 'osf.name',
	'tenant_id' => 'osf.tenant_id',
	'blocked' => 'me.blocked',
	'tags' => 'view.tags',
	'tenant_name' => 'osf.tenant_name',
	'properties' => 'view.properties',
    },

    Administrator => {
	'name' => 'me.name',
	'password' => 'me.password',
	'tenant_id' => 'me.tenant_id',
	'tenant_name' => 'me.tenant_name',
	'roles' => 'me.get_roles_info',
	'id' => 'me.id',
    },
    Tenant => {
	'name' => 'me.name',
	'id' => 'me.id'
    },

    Tenant_Views_Setup => { 	
	'id' => 'me.id', 
	'tenant_id' => 'me.tenant_id', 
	'field' => 'me.field', 
	'tenant_name' => 'tenant.name', 
	'visible' => 'me.visible',
	'view_type' => 'me.view_type',
	'device_type' => 'me.device_type',
	'qvd_object' => 'me.qvd_object',
	'property' => 'me.property'  
    },

    Administrator_Views_Setup =>  {
	'id' => 'me.id',  
	'tenant_id' => 'administrator.tenant_id', 
	'tenant_name' => 'administrator.tenant_name', 
	'admin_id' => 'me.administrator_id', 
	'field' => 'me.field', 
	'admin_name' => 'administrator.name',
	'visible' => 'me.visible',
	'view_type' => 'me.view_type',
	'device_type' => 'me.device_type',
	'qvd_object' => 'me.qvd_object',
	'property' => 'me.property'  
 }
};

my $VALUES_NORMALIZATOR = 
{ 
    DI => { disk_image => \&basename_disk_image},

    User => { name => \&normalize_name, 
	      password => \&password_to_token }
};


my $DBIX_JOIN_VALUE = 
{ 
    User => [qw(tenant), { vms => 'vm_runtime'}],
 
    VM => ['di', 'osf', { vm_runtime => 'host' }, { user => 'tenant' }],
  
    Host => ['runtime', 'vms'],

    OSF => [ qw(tenant vms), { dis => 'tags' }],

    DI => [qw(vm_runtimes tags), {osf => 'tenant'}],

    DI_Tag => [{di => {osf => 'tenant'}}],

    Role => [{role_rels => 'inherited'}, { acl_rels => 'acl'}],
		
    Administrator => [qw(tenant), { role_rels => { role => { acl_rels => 'acl' }}}],
    
    ACL => [{ role_rels => { role => { admin_rels => 'admin' }}}],
    
    Tenant_Views_Setup => [ qw(tenant)],

    Administrator_Views_Setup => [ { administrator => 'tenant' }] 
};

my $DBIX_PREFETCH_VALUE = 
{ 
    list => { User => [qw(tenant)],
	      VM => ['di', 'osf', { vm_runtime => 'host' }, { user => 'tenant' }],
	      Host => ['runtime'],
	      OSF => [ qw(tenant)],
	      DI => [{osf => 'tenant'}],
	      DI_Tag => [{di => {osf => 'tenant'}}],
	      Administrator => [qw(tenant)],
	      Tenant_Views_Setup => [ qw(tenant)],
	      Administrator_Views_Setup => [ { administrator => 'tenant' }] },

    details => {User => [qw(tenant)],
		VM => ['di', 'osf', { vm_runtime => 'host' }, { user => 'tenant' }],
		Host => ['runtime'],
		OSF => [ qw(tenant)],
		DI => [{osf => 'tenant'}],
		DI_Tag => [{di => {osf => 'tenant'}}],
		Administrator => [qw(tenant)],
		Tenant_Views_Setup => [ qw(tenant)],
		Administrator_Views_Setup => [ { administrator => 'tenant' }]}
};

my $DBIX_HAS_ONE_RELATIONSHIPS = 
{ 
    VM => [qw(vm_runtime counters)],
    Host => [qw(runtime counters)]
};

sub BUILD
{
    my $self = shift;

    $DBConfigProvider = QVD::Admin4::DBConfigProvider->new();

    $self->initialize_info_model;

    $self->set_info_by_type_of_action_and_qvd_object(
	'related_views_in_db',$RELATED_VIEWS_IN_DB);

    $self->set_info_by_type_of_action_and_qvd_object(
	'available_nested_queries',$AVAILABLE_NESTED_QUERIES);

    $self->set_info_by_type_of_action_and_qvd_object(
	'available_filters',$AVAILABLE_FILTERS);

    $self->set_info_by_type_of_action_and_qvd_object(
	'available_fields',$AVAILABLE_FIELDS,1);

    $self->set_info_by_type_of_action_and_qvd_object(
	'subchain_filters',$SUBCHAIN_FILTERS);

    $self->set_info_by_type_of_action_and_qvd_object(
	'commodin_filters',$COMMODIN_FILTERS);

    $self->set_info_by_type_of_action_and_qvd_object(
	'default_order_criteria',$DEFAULT_ORDER_CRITERIA);

    $self->set_info_by_qvd_object(
	'available_arguments',$AVAILABLE_ARGUMENTS);

    $self->set_info_by_qvd_object(
	'mandatory_arguments',$MANDATORY_ARGUMENTS);

    $self->set_info_by_type_of_action_and_qvd_object(
	'mandatory_filters',$MANDATORY_FILTERS);

    $self->set_info_by_qvd_object(
	'default_argument_values',$DEFAULT_ARGUMENT_VALUES);

    $self->set_info_by_qvd_object(
	'filters_to_dbix_format_mapper',$FILTERS_TO_DBIX_FORMAT_MAPPER);

    $self->set_info_by_qvd_object(
	'arguments_to_dbix_format_mapper',$ARGUMENTS_TO_DBIX_FORMAT_MAPPER);

    $self->set_info_by_qvd_object(
	'fields_to_dbix_format_mapper',$FIELDS_TO_DBIX_FORMAT_MAPPER);

    $self->set_info_by_qvd_object(
	'order_criteria_to_dbix_format_mapper',$ORDER_CRITERIA_TO_DBIX_FORMAT_MAPPER);

    $self->set_info_by_qvd_object(
	'nested_queries_to_admin4_mapper',$NESTED_QUERIES_TO_ADMIN4_MAPPER);

    $self->set_info_by_qvd_object(
	'values_normalizator',$VALUES_NORMALIZATOR);

    $self->set_info_by_qvd_object(
	'dbix_join_value',$DBIX_JOIN_VALUE);

    $self->set_info_by_type_of_action_and_qvd_object(
	'dbix_prefetch_value',$DBIX_PREFETCH_VALUE);

    $self->set_info_by_qvd_object(
	'dbix_has_one_relationships',$DBIX_HAS_ONE_RELATIONSHIPS);

    $self->set_tenant_fields;  # The last one. It depends on others
}

sub initialize_info_model 
{
    my $self = shift;
    $self->{model_info} =
{ 
    related_views_in_db => [],
    available_filters => [],                                                                 
    available_fields => [],                                                                  
    available_arguments => [],                                                               
    available_nested_queries => [],                                                               
    subchain_filters => [],                                                                 
    commodin_filters => [],                                                                  
    mandatory_arguments => [],                                                               
    mandatory_filters => [],                                                                 
    default_argument_values => {},                                                           
    default_order_criteria => [],                                                            
    filters_to_dbix_format_mapper => {},                                                     
    arguments_to_dbix_format_mapper => {},                                                   
    fields_to_dbix_format_mapper => {},                                                      
    order_criteria_to_dbix_format_mapper => {},                                              
    nested_queries_to_admin4_mapper => {},                                              
    values_normalizator => {},                                                               
    dbix_join_value => [],                                                                   
    dbix_prefetch_value => [],                                                                   
    dbix_has_one_relationships => []
};
}

sub set_tenant_fields
{
    my $self = shift;

    return unless $self->type_of_action =~ /^list|details$/;

    return unless $self->current_qvd_administrator->is_superadmin;

    push @{$self->{model_info}->{available_fields}},'tenant_id'
	if defined $self->fields_to_dbix_format_mapper->{tenant_id};

    push @{$self->{model_info}->{available_fields}},'tenant_name'
	if defined $self->fields_to_dbix_format_mapper->{tenant_name};
}

sub set_info_by_type_of_action_and_qvd_object
{
    my ($self,$model_info_key,$INFO_REPO,$flag) = @_;

    return unless exists $INFO_REPO->{$self->type_of_action};

    if (exists $INFO_REPO->{$self->type_of_action}->{$self->qvd_object}) 
    {
	$self->{model_info}->{$model_info_key} = 
	    clone $INFO_REPO->{$self->type_of_action}->{$self->qvd_object};
    }
    elsif (exists $INFO_REPO->{$self->type_of_action}->{default})
    {
	$self->{model_info}->{$model_info_key} = 
	    clone $INFO_REPO->{$self->type_of_action}->{default};
    }
}

sub set_info_by_qvd_object
{
    my ($self,$model_info_key,$INFO_REPO) = @_;

    $self->{model_info}->{$model_info_key} = 
	clone $INFO_REPO->{$self->qvd_object};
}

############
###########
##########

sub related_views_in_db
{
    my $self = shift;
    my $views = $self->{model_info}->{related_views_in_db} // [];
    @$views;
}

sub related_view
{
    my $self = shift;
    my $views = $self->{model_info}->{related_views_in_db} // [];
    my @views = @$views;
    return $views[0];
}

sub available_nested_queries
{
    my $self = shift;
    my $nq =  $self->{model_info}->{available_nested_queries} // [];
    @$nq;
}

sub available_filters
{
    my $self = shift;
    my $filters =  $self->{model_info}->{available_filters} // [];
    @$filters;
}

sub subchain_filters
{
    my $self = shift;
    my $filters = $self->{model_info}->{subchain_filters} // [];
    @$filters;
}

sub commodin_filters
{
    my $self = shift;

    my $filters = $self->{model_info}->{commodin_filters} // [];
    @$filters;
}

sub default_order_criteria
{
    my $self = shift;

    my $order_criteria = $self->{model_info}->{default_order_criteria} // [];
    @$order_criteria;
}

sub available_arguments
{
    my $self = shift;
    my $args = $self->{model_info}->{available_arguments} // [];
    @$args;
}

sub available_fields
{
    my $self = shift;

    my $fields = $self->{model_info}->{available_fields} // [];
    @$fields;
}

sub mandatory_arguments
{
    my $self = shift;
    my $args =  $self->{model_info}->{mandatory_arguments} // [];
    @$args;
}

sub mandatory_filters
{
    my $self = shift;

    my $filters = $self->{model_info}->{mandatory_filters} // [];
    @$filters;
}

sub default_argument_values
{
    my $self = shift;
    return $self->{model_info}->{default_argument_values} || {};
}


sub nested_queries_to_admin4_mapper
{
    my $self = shift;
    return $self->{model_info}->{nested_queries_to_admin4_mapper} || {};
}

sub filters_to_dbix_format_mapper
{
    my $self = shift;
    return $self->{model_info}->{filters_to_dbix_format_mapper} || {};
}

sub order_criteria_to_dbix_format_mapper
{
    my $self = shift;
    return $self->{model_info}->{order_criteria_to_dbix_format_mapper} || {};
}


sub arguments_to_dbix_format_mapper
{
    my $self = shift;
    return $self->{model_info}->{arguments_to_dbix_format_mapper} || {};
}

sub fields_to_dbix_format_mapper
{
    my $self = shift;
    return $self->{model_info}->{fields_to_dbix_format_mapper} || {};
}

sub values_normalizator
{
    my $self = shift;
    return $self->{model_info}->{values_normalizator} || {};
}

sub dbix_join_value
{
    my $self = shift;
    return $self->{model_info}->{dbix_join_value} || [];
}

sub dbix_prefetch_value
{
    my $self = shift;
    return $self->{model_info}->{dbix_prefetch_value} || [];
}

sub dbix_has_one_relationships
{
    my $self = shift;
    my $rels = $self->{model_info}->{dbix_has_one_relationships} // [];
    @$rels;
}

#################
################
#################

sub related_view_in_db
{
    my $self = shift;
    my $view = shift;
    $_ eq $view && return 1
	for $self->related_views_in_db;
    return 0;
}


sub available_nested_query
{
    my $self = shift;
    my $nq = shift;
    $_ eq $nq && return 1
	for $self->available_nested_queries;

    return 0;
}

sub available_filter
{
    my $self = shift;
    my $filter = shift;
    $_ eq $filter && return 1
	for $self->available_filters;

    return 0;
}

sub subchain_filter
{
    my $self = shift;
    my $filter = shift;

    $_ eq $filter && return 1
	for $self->subchain_filters;
    return 0;
}

sub commodin_filter
{
    my $self = shift;
    my $filter = shift;

    $_ eq $filter && return 1
	for $self->commodin_filters;
    return 0;
}

sub default_order_criterium
{
    my $self = shift;
    my $order_criterium = shift;
    $_ eq $order_criterium && return 1
	for $self->default_order_criteria;
    return 1;
}

sub available_argument
{
    my $self = shift;
    my $argument = shift;

    $_ eq $argument && return 1
	for $self->available_arguments;

    return 0;
}

sub available_field
{
    my $self = shift;
    my $field = shift;
    $_ eq $field && return 1
	for $self->available_fields;

    return 0;
}

sub mandatory_argument
{
    my $self = shift;
    my $argument = shift;

    $_ eq $argument && return 1
	for $self->mandatory_arguments;
    return 0;
}

sub mandatory_filter
{
    my $self = shift;
    my $filter = shift;
    $_ eq $filter && return 1
	for $self->mandatory_filters;
    return 0;
}

sub get_default_argument_value
{
    my $self = shift;
    my $arg = shift;

    my $def = $self->default_argument_values->{$arg} // return; 
    return ref($def) ? $def->() : $def;
}

sub map_filter_to_dbix_format
{
    my $self = shift;
    my $filter = shift;

    my $mapped_filter = $self->filters_to_dbix_format_mapper->{$filter};
    defined $mapped_filter
    || die "No mapping available for filter $filter";
    return $mapped_filter;
}

sub map_argument_to_dbix_format
{
    my $self = shift;
    my $argument = shift;
    my $mapped_argument = $self->arguments_to_dbix_format_mapper->{$argument};
    defined $mapped_argument
    || die "No mapping available for argument $argument";
    $mapped_argument;
}

sub map_nested_query_to_admin4
{
    my $self = shift;
    my $nq = shift;
    my $mapped_nq = $self->nested_queries_to_admin4_mapper->{$nq};
    defined $mapped_nq
    || die "No mapping available for nested query $nq";
    $mapped_nq;
}

sub map_field_to_dbix_format
{
    my $self = shift;
    my $field = shift;

    my $mapped_field = $self->fields_to_dbix_format_mapper->{$field};
    defined $mapped_field
    || die "No mapping available for field $field";

    return $mapped_field;
}

sub map_order_criteria_to_dbix_format
{
    my $self = shift;
    my $oc = shift;
    my $mapped_oc = $self->order_criteria_to_dbix_format_mapper->{$oc};
    defined $mapped_oc ||  die "No mapping available for order_criteria $oc";

    return $mapped_oc;
}

sub normalize_value
{
    my $self = shift;
    my $key = shift;
    my $value = shift;

    $self->values_normalizator || return $value;
    my $norm = $self->values_normalizator->{$key} // 
	return $value; 

    return ref($norm) ? $self->$norm($value) : $norm;
}

sub get_default_memory { cfg('osf.default.memory'); }
sub get_default_overlay { cfg('osf.default.overlay'); }
sub basename_disk_image { my $self = shift; basename(+shift); };

sub password_to_token 
{
    my ($self, $password) = @_;
    require Digest::SHA;
    Digest::SHA::sha256_base64(cfg('l7r.auth.plugin.default.salt') . $password);
}

sub normalize_name
{
    my ($self,$login) = @_;
    $login =~ s/^\s*//; $login =~ s/\s*$//;
    $login = lc($login)  
	unless cfg('model.user.login.case-sensitive');
    $login;
}

sub get_free_ip {

    my $nettop = nettop_n;
    my $netstart = netstart_n;

    my %ips = map { net_aton($_->ip) => 1 } 
    $DBConfigProvider->db->resultset('VM')->all;

    while ($nettop-- > $netstart) {
        return net_ntoa($nettop) unless $ips{$nettop}
    }
    die "No free IP addresses";
}

##################
######## ACLS
##################

sub get_acls_for_filter
{
    my ($self,$filter) = @_;
    $self->get_acls($ACLS_FOR_FILTERS,$filter);
}

sub get_acls_for_field
{
    my ($self,$field) = @_;
    $self->get_acls($ACLS_FOR_FIELDS,$field);
}

sub get_acls_for_argument_in_creation
{
    my ($self,$arg) = @_;
    $self->get_acls($ACLS_FOR_ARGUMENTS_IN_CREATION,$arg);
}

sub get_acls_for_argument_in_update
{
    my ($self,$arg) = @_;
    $self->get_acls($ACLS_FOR_ARGUMENTS_IN_UPDATE,$arg);
}
    
sub get_acls_for_argument_in_massive_update
{
    my ($self,$arg) = @_;
    $self->get_acls(
	$ACLS_FOR_ARGUMENTS_IN_MASSIVE_UPDATE,$arg);
}

sub get_acls_for_nested_query_in_creation
{
    my ($self,$nq) = @_;
    $self->get_acls(
	$ACLS_FOR_ARGUMENTS_IN_CREATION,$nq);
}

sub get_acls_for_nested_query_in_update
{
    my ($self,$nq) = @_;
    $self->get_acls(
	$ACLS_FOR_ARGUMENTS_IN_UPDATE,$nq);
}
    
sub get_acls_for_nested_query_in_massive_update
{
    my ($self,$nq) = @_;
    $self->get_acls(
	$ACLS_FOR_ARGUMENTS_IN_MASSIVE_UPDATE,$nq);
}

sub get_acls_for_delete_massive
{
    my $self = shift;
    $self->get_acls(
	$ACLS_FOR_ARGUMENTS_IN_MASSIVE_UPDATE,'***delete***');
}

sub get_acls
{
    my ($self,$REPO,$filter) = @_;
    return () unless defined $REPO->{$self->qvd_object};
    return () unless defined $REPO->{$self->qvd_object}->{$filter};
    my @acls = @{$REPO->{$self->qvd_object}->{$filter}};
}

1;
