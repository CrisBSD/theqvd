use Test::More;
use Test::Mojo;
use FindBin;
require "$FindBin::Bin/../bin/wat.pl";

my $t = Test::Mojo->new;

#################
### user_create
#################

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'user_update',
			     filters    => { id => 5 },
			     arguments => { name => 'benja',
					    password => 'benjamin',
					    blocked => 1,
			                    __properties_changes__ => { set => { age => 20, 
										 kk => 'kk'}, 
									delete => ['world']}}}) 
    ->status_is(200, 'user_update HTTP STATUS')
    ->json_is('/status' => '0', 'user_update API STATUS');

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'user_get_details',
			     filters    => { id => 5 }}) 
    ->status_is(200, 'user_get_details HTTP STATUS')
    ->json_is('/status' => '0', 'user_get_details API STATUS')
    ->json_is('/result/rows/0/name' => 'benja', 'user_get_details HAS CHANGED')
    ->json_is('/result/rows/0/blocked' => '1', 'user_get_details HAS CHANGED')
    ->json_is('/result/rows/0/properties/age' => '20', 'user_get_details HAS CHANGED')
    ->json_is('/result/rows/0/properties/kk' => 'kk', 'user_get_details HAS CHANGED')
    ->json_hasnt('/result/rows/0/properties/world', 'user_get_details HAS CHANGED');


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'user_update',
			     filters    => { id => 5 },
			     arguments => { name => 'ben',
					    password => 'benja',
					    blocked => 0,
					    __properties_changes__ => { set => { age => 30, 
										 world => 'reality'}, 
									delete => ['kk']}}}) 
    ->status_is(200, 'user_update HTTP STATUS')
    ->json_is('/status' => '0', 'user_update API STATUS');

#################
### vm_update
#################


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'vm_update',
			     filters    => { id => 4 },
			     arguments => { di_tag =>'kkk' ,
			                    storage => 10, 
					    name => 'buenavm', 
					    blocked => 1,
					    expiration_soft => '10/10/2014',
					    expiration_hard => '10/10/2014',
					    ip => '10.0.255.200',
					    __properties_changes__ => { set => { kk => 'kk'}, 
									delete => ['world']}}}) 
    ->status_is(200, 'vm_update HTTP STATUS')
    ->json_is('/status' => '0', 'vm_update API STATUS');

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'vm_get_details',
			     filters    => { id => 4 }}) 
    ->status_is(200, 'vm_get_details HTTP STATUS')
    ->json_is('/status' => '0', 'vm_get_details API STATUS')
    ->json_is('/result/rows/0/name' => 'buenavm', 'vm_get_details HAS CHANGED')
    ->json_is('/result/rows/0/storage' => '10', 'vm_get_details HAS CHANGED')
    ->json_is('/result/rows/0/blocked' => '1', 'vm_get_details HAS CHANGED')
    ->json_is('/result/rows/0/expiration_soft' => '10/10/2014', 'vm_get_details HAS CHANGED')
    ->json_is('/result/rows/0/expiration_hard' => '10/10/2014', 'vm_get_details HAS CHANGED')
    ->json_is('/result/rows/0/ip' => '10.0.255.200', 'vm_get_details HAS CHANGED')
    ->json_is('/result/rows/0/properties/kk' => 'kk', 'vm_get_details HAS CHANGED')
    ->json_hasnt('/result/rows/0/properties/world','vm_get_details HAS CHANGED');


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'vm_update',
			     filters    => { id => 4 },
			     arguments => { di_tag =>'default' ,
			                    storage => undef, 
					    name => 'kkdevm', 
					    blocked => 0,
					    expiration_soft => undef,
					    expiration_hard => undef,
					    ip => '10.0.255.254',
					    __properties_changes__ => { set => { world => 'qvd'}, 
									delete => ['kk']}}}) 
    ->status_is(200, 'vm_update HTTP STATUS')
    ->json_is('/status' => '0', 'vm_update API STATUS');

#################
### host_update
#################


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'host_update',
			     filters    => { id => 1},
			     arguments => { name => 'QVD1_Lite',
					    address => '10.0.0.66',
					    blocked => 1,
					    __properties_changes__ => { set => { kk => 'kk'}, 
									delete => ['world']}}}) 
    ->status_is(200, 'host_update HTTP STATUS')
    ->json_is('/status' => '0', 'host_update API STATUS');

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'host_get_details',
			     filters    => { id => 1}}) 
    ->status_is(200, 'host_get_details HTTP STATUS')
    ->json_is('/status' => '0', 'host_get_details API STATUS')
    ->json_is('/result/rows/0/name' => 'QVD1_Lite', 'host_get_details HAS CHANGED')
    ->json_is('/result/rows/0/address' => '10.0.0.66', 'host_get_details HAS CHANGED')
    ->json_is('/result/rows/0/blocked' => '1', 'host_get_details HAS CHANGED')
    ->json_is('/result/rows/0/properties/kk' => 'kk', 'host_get_details HAS CHANGED')
    ->json_hasnt('/result/rows/0/properties/world', 'host_get_details HAS CHANGED');
  

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'host_update',
			     filters    => { id => 1},
			     arguments => { name => 'QVD1',
					    address => '10.0.0.1',
					    blocked => 0,
					    __properties_changes__ => { set => { world => 'qvd'}, 
									delete => ['kk']}}}) 
    ->status_is(200, 'host_update HTTP STATUS')
    ->json_is('/status' => '0', 'host_update API STATUS');

#################
### osf_update
#################

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'osf_update',
			     filters    => { id => 1 },
			     arguments => { name => 'Developers',
					    overlay => 0,
					    user_storage => 1,
					    memory => 257 }}) 
    ->status_is(200, 'osf_update HTTP STATUS')
    ->json_is('/status' => '0', 'osf_update API STATUS');


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'osf_get_details',
			     filters    => { id => 1 }}) 
    ->status_is(200, 'osf_get_detais HTTP STATUS')
    ->json_is('/status' => '0', 'osf_get_details API STATUS')
    ->json_is('/result/rows/0/name' => 'Developers', 'osf_get_details HAS CHANGED')
    ->json_is('/result/rows/0/overlay' => 0, 'osf_get_details HAS CHANGED')
    ->json_is('/result/rows/0/user_storage' => 1, 'osf_get_details HAS CHANGED')
    ->json_is('/result/rows/0/memory' => 257, 'osf_get_details HAS CHANGED');

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'osf_update',
			     filters    => { id => 1 },
			     arguments => { name => 'Accountants',
					    overlay => 1,
					    user_storage => 0,
					    memory => 256 }}) 
    ->status_is(200, 'osf_update HTTP STATUS')
    ->json_is('/status' => '0', 'osf_update API STATUS');

#################
### di_update
#################

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'di_update',
			     filters    => { id => 5 },
			     arguments => {blocked => 1,
			                   disk_image => 'OPEN',
					    __properties_changes__ => { set => { kk => 'kk'}, 
									delete => ['world']},
					   __tags_changes__ => { create => ['kk']}}}) 
    ->status_is(200, 'di_update HTTP STATUS')
    ->json_is('/status' => '0', 'di_update API STATUS');


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'di_get_details',
			     filters    => { id => 5 }}) 
    ->status_is(200, 'di_get_details HTTP STATUS')
    ->json_is('/status' => '0', 'di_get_details API STATUS')
    ->json_is('/result/rows/0/disk_image' => 'OPEN', 'di_get_details HAS CHANGED')
    ->json_is('/result/rows/0/properties/kk' => 'kk', 'di_get_details HAS CHANGED')
    ->json_hasnt('/result/rows/0/properties/world', 'di_get_details HAS CHANGED')
    ->json_is('/result/rows/0/tags/3/tag' => 'kk', 'di_get_details HAS CHANGED');


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'di_update',
			     filters    => { id => 5 },
			     arguments => {blocked => 0,
			                   disk_image => 'opensuse',
					    __properties_changes__ => { set => { world => 'qvd'}, 
									delete => ['kk']},
					   __tags_changes__ => { delete => ['kk']}}}) 
    ->status_is(200, 'di_update HTTP STATUS')
    ->json_is('/status' => '0', 'di_update API STATUS');


#################
### admin_update
#################

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'admin_update',
			     filters => {id => 5},
			     arguments    => { name => 'youradmin',
			                       password => 'youradmin',
					       __roles_changes__ => { assign_roles => ['4'], 
								      unassign_roles => ['1']}}}) 
    ->status_is(200, 'admin_update HTTP STATUS')
    ->json_is('/status' => '0', 'admin_update API STATUS');


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'admin_get_details',
			     filters => {id => 5}}) 
    ->status_is(200, 'admin_get_details HTTP STATUS')
    ->json_is('/result/rows/0/name' => 'youradmin', 'admin_get_details HAS CHANGED')
    ->json_is('/result/rows/0/roles/0/name','superpringao', 'admin_get_details HAS CHANGED')
    ->json_hasnt('/result/rows/0/roles/1/','admin_get_details HAS CHANGED')
    ->json_is('/result/rows/0/acls/0/name','user_see', 'admin_get_details HAS CHANGED')
    ->json_hasnt('/result/rows/0/acls/1/','admin_get_details HAS CHANGED')
    ->json_is('/status' => '0', 'admin_get_details API STATUS');

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'admin_update',
			     filters => {id => 5},
			     arguments    => { name => 'myadmin',
			                       password => 'myadmin',
					       __roles_changes__ => { assign_roles => ['1'], 
								      unassign_roles => ['4']}}}) 
    ->status_is(200, 'admin_update HTTP STATUS')
    ->json_is('/status' => '0', 'admin_update API STATUS');

#################
### tenant_update
#################

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'tenant_update',
			     filters => {id => 1},
			     arguments    => { name => 'Barcelona' }}) 
    ->status_is(200, 'tenant_update HTTP STATUS')
    ->json_is('/status' => '0', 'tenant_update API STATUS');


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'tenant_get_details',
			     filters => {id => 1},
			     arguments    => { name => 'Barcelona' }}) 
    ->status_is(200, 'tenant_get_details HTTP STATUS')
    ->json_is('/status' => '0', 'tenant_get_details API STATUS')
    ->json_is('/result/rows/0/name' => 'Barcelona', 'tenant_get_details HAS CHANGED');


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'tenant_update',
			     filters => {id => 1},
			     arguments    => { name => 'Madrid' }}) 
    ->status_is(200, 'tenant_update HTTP STATUS')
    ->json_is('/status' => '0', 'tenant_update API STATUS');

#################
### role_update
#################

$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'role_update',
			     filters    => {id => 4 },
	                     arguments => {name => 'superpringate',
					   __acls_changes__ => { assign_roles => ['1'], 
								 assign_acls => ['4'], 
								 unassign_roles => [], 
								 unassign_acls => ['2'] }}}) 
    ->status_is(200, 'role_update HTTP STATUS')
    ->json_is('/status' => '0', 'role_update API STATUS');


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'role_get_details',
			     filters    => {id => 4 }}) 
    ->status_is(200, 'role_get_details HTTP STATUS')
    ->json_is('/status' => '0', 'role_get_details API STATUS')

    ->json_is('/result/rows/0/name' => 'superpringate', 'role_get_details HAS CHANGED')
    ->json_is('/result/rows/0/roles/0/name','spy', 'role_get_details HAS CHANGED')
    ->json_hasnt('/result/rows/0/roles/1/','role_get_details HAS CHANGED')
    ->json_is('/result/rows/0/acls/0/name', 'user_delete', 'role_get_details HAS CHANGED')
    ->json_is('/result/rows/0/acls/1/name','user_see', 'role_get_details HAS CHANGED')
    ->json_is('/result/rows/0/acls/2/name','user_update', 'role_get_details HAS CHANGED')
    ->json_hasnt('/result/rows/0/acls/3/', 'role_get_details HAS CHANGED')
;


$t->post_ok('/' => json => { login    => 'superadmin',              
		             password => 'superadmin',              
		             action   => 'role_update',
			     filters    => {id => 4 },
	                     arguments => {name => 'superpringao',
			     __acls_changes__ => { assign_roles => [], 
						   assign_acls => ['1'], 
						   unassign_roles => ['1'], 
						   unassign_acls => ['4'] }}}) 
    ->status_is(200, 'role_update HTTP STATUS')
    ->json_is('/status' => '0', 'role_update API STATUS');


##
done_testing();
##
###################################
###################################
###################################
##
#
