package QVD::Admin4::CLI::Command;
use strict;
use warnings;
use base qw( CLI::Framework::Command::Meta );
use Text::SimpleTable::AutoWidth;
use Mojo::JSON qw(encode_json decode_json j);
use Mojo::IOLoop;
use Mojo::Message::Response;

my $LOGICAL_OPERATORS = { -and => 1, -or => 1, -not => 1 };

my $FILTERS =
{
    vm => { storage => 'storage', id => 'id', name => 'name', user => 'user_name', osf => 'osf_name', tag => 'di_tag', blocked => 'blocked', 
	    expiration_soft => 'expiration_soft', expiration_hard => 'expiration_hard', state => 'state', host =>  'host_name', di => 'di_name', 
	    user_state => 'user_state', ip => 'ip', ssh_port => 'ssh_port', vnc_port => 'vnv_port', serial_port => 'serial_port',
	    tenant =>  'tenant_name', ip_in_use => 'ip_in_use', di_in_use => 'di_name_in_use' },

    user => { id => 'id', name => 'name', blocked => 'blocked', tenant => 'tenant_name'},

    host => { id => 'id', name => 'name', address => 'address', blocked => 'blocked', frontend => 'frontend', backend => 'backend', state => 'state'},

    osf => { id => 'id', name => 'name', overlay => 'overlay', user_storage => 'user_storage', memory => 'memory', tenant =>  'tenant_name' },

    di => { id => 'id', name => 'disk_image', version => 'version', osf => 'osf_name', tenant => 'tenant_name', blocked => 'blocked', tag => 'tag' },

    tenant => { id => 'id', name => 'name', language => 'language', block => 'block' },

    config => { key_re => 'key_re' },

    admin => { id => 'id', name => 'name', tenant => 'tenant_name', language => 'language', block => 'block' },

    role => { id => 'id', name => 'name', fixed => 'fixed', internal => 'internal' },

    acl => { id => 'id', name => 'name', role => 'role_id', admin => 'admin_id', operative => 'operative'},
};


my $ORDER =
{
    vm => { storage => 'storage', id => 'id', name => 'name', user => 'user_name', osf => 'osf_name', tag => 'di_tag', blocked => 'blocked', 
	    expiration_soft => 'expiration_soft', expiration_hard => 'expiration_hard', state => 'state', host =>  'host_name', di => 'di_name', 
	    user_state => 'user_state', ip => 'ip', ssh_port => 'ssh_port', vnc_port => 'vnv_port', serial_port => 'serial_port',
	    tenant =>  'tenant_name', ip_in_use => 'ip_in_use'},

    user => { id => 'id', name => 'name', blocked => 'blocked', tenant => 'tenant_name'},

    host => { id => 'id', name => 'name', address => 'address', blocked => 'blocked', frontend => 'frontend', backend => 'backend',state => 'state'},

    osf => { id => 'id', name => 'name', overlay => 'overlay', user_storage => 'user_storage', memory => 'memory', tenant =>  'tenant_name' },

    di => { id => 'id', name => 'disk_image', version => 'version', osf => 'osf_name', tenant => ' tenant_name', blocked => 'blocked', tag => 'tag' },

    tenant => { id => 'id', name => 'name', language => 'language', block => 'block' },

    admin => { id => 'id', name => 'name', tenant => 'tenant_name', language => 'language', block => 'block' },

    role => { id => 'id', name => 'name', fixed => 'fixed', internal => 'internal' },

    acl => { id => 'id', name => 'name' }
};

my $FIELDS =
{
    vm => { storage => 'storage', id => 'id', name => 'name', user => 'user_name', osf => 'osf_name', tag => 'di_tag', blocked => 'blocked', 
	    expiration_soft => 'expiration_soft', expiration_hard => 'expiration_hard', state => 'state', host =>  'host_name', di => 'di_name', 
	    user_state => 'user_state', ip => 'ip', mac => 'mac', ssh_port => 'ssh_port', vnc_port => 'vnv_port', serial_port => 'serial_port', 
	    tenant =>  'tenant_name', ip_in_use => 'ip_in_use', di_in_use => 'di_name_in_use' },

    user => { id => 'id', name => 'name', tenant => 'tenant_name', blocked => 'blocked', number_of_vms => 'number_of_vms', number_of_vms_connected => 'number_of_vms_connected'},

    host => { id => 'id', name => 'name', address => 'address', blocked => 'blocked', frontend => 'frontend', backend => 'backend', state => 'state', number_of_vms_connected => 'number_of_vms_connected'},

    osf => { id => 'id', name => 'name', overlay => 'overlay', user_storage => 'user_storage', memory => 'memory', tenant =>  'tenant_name', number_of_vms => 'number_of_vms', number_of_dis => 'number_of_dis'},

    di => { id => 'id', name => 'disk_image', tenant => 'tenant_name', version => 'version', osf => 'osf_name', blocked => 'blocked', tags => 'tags'},

    tenant => { id => 'id', name => 'name', language => 'language', block => 'block' },

    config => { key => 'key', value => 'operative_value' },

    admin => { id => 'id', name => 'name', roles => 'roles', tenant => 'tenant_name', language => 'language', block => 'block' },

    role => { id => 'id', name => 'name', fixed => 'fixed', internal => 'internal', roles => 'roles', acls => 'acls'},

    acl => { id => 'id', name => 'name' }
};

my $FIELDS_CBS =
{
    di => { tags => sub { my $tags = shift; my @tags = map { $_->{tag} } @$tags; return join ', ', @tags; }},

    admin => { roles => sub { my $roles = shift; my @roles =  values %$roles; return join "\n", @roles }},

    role => { roles => sub { my $roles = shift; my @roles = map { $_->{name} } values %$roles; return join "\n", @roles},
	      acls =>  sub { my $acls = shift; my @acls = sort ( (map { "$_ (+)" } @{$acls->{positive}}), (map { "$_ (-)" } @{$acls->{negative}})); return join "\n", @acls}},

};

my $ARGUMENTS =
{
    vm => { name => 'name', ip => 'ip', tenant => 'tenant_id', blocked => 'blocked', expiration_soft => 'expiration_soft',
	    expiration_hard => 'expiration_hard', storage => 'storage', tag => 'di_tag', user => 'user_id', osf => 'osf_id', 
	    __properties_changes__ => '__properties_changes__' },

    user => { name => 'name', password => 'password', blocked => 'blocked', tenant => 'tenant_id',
	      __properties_changes__ => '__properties_changes__' },

    host => { name => 'name', address => 'address', frontend => 'frontend', backend => 'backend', blocked => 'blocked',
	      __properties_changes__ => '__properties_changes__' },

    osf => { name => 'name', memory => 'memory', user_storage => 'user_storage', overlay => 'overlay', tenant => 'tenant_id',
	     __properties_changes__ => '__properties_changes__' },

    di => { blocked => 'blocked',  name => 'disk_image',  version => 'version', osf => 'osf_id',
	    __properties_changes__ => '__properties_changes__', __tags_changes__ => '__tags_changes__'},

    tenant => { name => 'name', language => 'language', block => 'block' },

    config => { key => 'key', value => 'value' },

    admin => { name => 'name', password => 'password', tenant => 'tenant_id', language => 'language', block => 'block',
	       __roles_changes__ => '__roles_changes__' },

    role => { name => 'name', fixed => 'fixed', internal => 'internal',
	      __roles_changes__ => '__roles_changes__', __acls_changes__ => '__acls_changes__' },
};

my $related_tenant_cb = sub { 
    my ($self,$name) = @_; 
    $self->ask_api({ action => 'tenant_all_ids', 
		     filters =>  { name => $name }})->json('/rows');
};

my $related_user_cb = sub { 
    my ($self,$name,$tenant_id) = @_; 
    my $filters = { name => $name };
    $filters->{tenant_id} = $tenant_id if $tenant_id;
    $self->ask_api( { action => 'user_all_ids', 
		      filters =>  $filters })->json('/rows');
};

my $related_host_cb = sub { 
    my ($self,$name) = @_; 
    $self->ask_api({ action => 'host_all_ids', 
		     filters =>  { name => $name }})->json('/rows');
};

my $related_osf_cb = sub { 
    my ($self,$name,$tenant_id) = @_; 
    my $filters = { name => $name };
    $filters->{tenant_id} = $tenant_id if $tenant_id;
    $self->ask_api( { action => 'osf_all_ids', 
		      filters =>  $filters })->json('/rows');
};

my $related_di_cb = sub { 
    my ($self,$name,$tenant_id) = @_; 
    my $filters = { name => $name };
    $filters->{tenant_id} = $tenant_id if $tenant_id;
    $self->ask_api( { action => 'di_all_ids', 
		      filters =>  $filters })->json('/rows');
};

my $related_admin_cb = sub { 
    my ($self,$name,$tenant_id) = @_; 
    my $filters = { name => $name };
    $filters->{tenant_id} = $tenant_id if $tenant_id;
    $self->ask_api( { action => 'admin_all_ids', 
		      filters =>  $filters })->json('/rows');
};

my $related_role_cb = sub { 
    my ($self,$name) = @_; 
    $self->ask_api({ action => 'role_all_ids', 
		     filters =>  { name => $name }})->json('/rows');
};

my $CBS_TO_GET_RELATED_OBJECTS_IDS =
{
    vm => { argument =>  { user => $related_user_cb,host => $related_host_cb,
			   osf => $related_osf_cb, di => $related_di_cb }},

    di => { argument => {osf => $related_osf_cb }}
};

my $CLI_CMD2API_ACTION =
{
    vm => { ids => 'vm_all_ids',  get => 'vm_get_list', update => 'vm_update', create => 'vm_create', delete => 'vm_delete', 
	    start => 'vm_start', stop => 'vm_stop', disconnect => 'vm_user_disconnect' },

    user => { ids => 'user_all_ids', get => 'user_get_list', update => 'user_update', create => 'user_create', delete => 'user_delete' },

    host => { ids => 'host_all_ids', get => 'host_get_list', update => 'host_update', create => 'host_create', delete => 'host_delete'},

    osf => { ids => 'osf_all_ids', get => 'osf_get_list', update => 'osf_update', create => 'osf_create', delete => 'osf_delete'},

    di => { ids => 'di_all_ids', get => 'di_get_list', update => 'di_update', create => 'di_create', delete => 'di_delete'},

    tenant => { ids => 'tenant_all_ids', get => 'tenant_get_list', update => 'tenant_update', create => 'tenant_create', delete => 'tenant_delete' },

    config => { get => 'config_get', update => 'config_set', delete => 'config_delete' },

    admin => { ids => 'admin_all_ids', get => 'admin_get_list', update => 'admin_update', create => 'admin_create', delete => 'admin_delete' },

    role => { ids => 'role_all_ids', get => 'role_get_list', update => 'role_update', create => 'role_create', delete => 'role_delete' },

    acl => { get => 'acl_get_list' }, 
};


my $DEFAULT_FIELDS = 
{ 
    vm => [ qw( id tenant name blocked user host di ip ip_in_use di_in_use state user_state ) ],

    user => [ qw( id tenant name blocked number_of_vms number_of_vms_connected ) ],

    host => [ qw( id name blocked address frontend backend state number_of_vms_connected ) ],

    osf => [ qw( id name overlay user_storage memory tenant number_of_vms number_of_dis ) ],

    di => [ qw( id tenant name version osf blocked tags ) ],

    tenant => [ qw( id name language block ) ],

    config => [ qw( key value ) ],

    admin => [ qw(id tenant name language block) ],

    role => [ qw(id name fixed internal) ],

    acl => [ qw(id name) ],
};

###############
## UTILITIES ##
###############

sub _get 
{
    my ($self,$parsing) = @_;
    my $query = $self->make_api_query($parsing);
    my $res = $self->ask_api($query);
    $self->print_table($res,$parsing);
}

sub _create 
{
    my ($self,$parsing) = @_;

    if (my $tenant_name = $parsing->arguments->{tenant})
    {
	my $tenant_ids = $related_tenant_cb->($self,$tenant_name);
	$self->tenant_scoop(shift @$tenant_ids);
	$parsing->arguments->{tenant} = $self->tenant_scoop; 
    }
  
    my $query = $self->make_api_query($parsing);

    my $res = $self->ask_api($query);
    $self->print_table($res,$parsing);
}

sub _can
{
    my ($self,$parsing) = @_;

    my $ids = $self->ask_api({ action => $self->get_all_ids_action($parsing),
			       filters => $self->get_filters($parsing) })->json('/rows');

    my $acl_name = $parsing->parameters->{acl_name}; 
    my $id_key = $parsing->qvd_object eq 'admin' ? 'admin_id' : 'role_id';
    my $filters = { $id_key => $ids, operative => 1 }; 
    $filters->{acl_name} = { 'LIKE' => $acl_name } if defined $acl_name;
    my $action = $parsing->qvd_object eq 'admin' ? 'get_acls_in_admins' : 'get_acls_in_roles';

    my $res = $self->ask_api({ action => $action,filters => $filters,order_by => $self->get_order($parsing)});
    $self->print_table($res,QVD::Admin4::CLI::Grammar::Response->new(
			   response => { command => 'get', obj1 => { qvd_object => 'acl' }}));
}

sub _cmd
{
    my ($self,$parsing) = @_;

    my $ids = $self->ask_api(
	{ action => $self->get_all_ids_action($parsing),
	  filters => $self->get_filters($parsing) })->json('/rows');
    
    my $res = $self->ask_api(
	{ action => $self->get_action($parsing),
	  filters => { id => { '=' => $ids }}, 
	  order_by => $self->get_order($parsing), 
	  arguments => $self->get_arguments($parsing)});

    $self->print_table($res,$parsing);
}

sub run 
{
    my ($self, $opts, @args) = @_;

    my $parsing = $self->parse_string(@args);

    if ($parsing->command eq 'get')
    {
	$self->_get($parsing);
    }
    elsif ($parsing->command eq 'create')
    {
	$self->_create($parsing);
    }
    elsif ($parsing->command eq 'can')
    {
	$self->_can($parsing);
    }
    else
    {
	$self->_cmd($parsing);
    }
}

sub make_api_query
{
    my ($self,$parsing) = @_;

    return { action => $self->get_action($parsing),
	     filters => $self->get_filters($parsing), 
	     fields => $self->get_fields_for_api($parsing), 
	     order_by => $self->get_order($parsing), 
	     arguments => $self->get_arguments($parsing)};
}

sub print_count
{
    my ($self,$res) = @_;
    print  "Total: ".$res->json('/total')."\n";
}

sub print_table
{
    my ($self,$res,$parsing) = @_;
    my $n = 0;    

    my @fields = $self->get_fields($parsing,$res);

    unless (@fields) { $self->print_count($res); return; }

    my $tb = Text::SimpleTable::AutoWidth->new();
    $tb->max_width(500);
    $tb->captions(\@fields);
    
    my $rows;
    while (my $properties = $res->json("/rows/$n")) 
    {	
	$tb->row( map { $self->get_field_value($parsing,$properties,$_) // '' } @fields );
	$n++;
    }

    print  $tb->draw . "Total: ".$res->json('/total')."\n";
}

sub parse_string
{
    my ($self,@args) = @_;
    my $req = join(' ',@args);
    my $app = $self->get_app;
    my ($tokenizer,$parser) = 
	($app->cache->get('tokenizer'), 
	 $app->cache->get('parser'));

    my $tokenization = $tokenizer->parse($req);

    $self->unrecognized($tokenization) &&
	die 'Unable to tokenize request';

    my $parsing = $parser->parse( shift @$tokenization );

    $self->unrecognized($parsing) &&
	die 'Unable to parse request';
    $self->ambiguous($parsing) &&
	die 'Ambiguos request';
    
    shift @$parsing;
}

sub unrecognized
{
    my ($self,$response) = @_;
    scalar @$response < 1 ? return 1 : 0; 
}

sub ambiguous
{
    my ($self,$response) = @_;
    scalar @$response > 1 ? return 1 : 0; 
}

sub ask_api
{
    my ($self,$query) = @_;
 
    return $self->ask_api_ws($query)
	if $query->{action} eq 'di_create';

    my $app = $self->get_app;
    my %args = (
	login => $app->cache->get('login'), 
	password => $app->cache->get('password'),
	sid => $app->cache->get('sid'),
	url => $app->cache->get('api'),
	ua =>  $app->cache->get('ua'));

    my ($sid,$login,$password,$url,$ua) = 
	@args{qw(sid login password url ua)};

    my %credentials = defined $sid ? (sid => $sid) : 
	( login => $login, password => $password );

    my $res = $ua->post("$url", json => {%$query,%credentials})->res;

    die 'API returns bad status' 
	unless $res->code;

    $self->check_api_result($res);
    return $res;
}

sub check_api_result
{
    my ($self,$res) = @_;

    return 1 unless $res->json('/status');
    die $res->json('/message') unless 
	$res->json('/status') eq 1200;

    my ($message,$failures) = ('',$res->json('/failures'));

    while (my ($id,$failure) = each %$failures)
    {
	$message .= "$id: " . $failure->{message} . "\n";
    } 
    die $message;
}


sub ask_api_ws
{
    my ($self,$query) = @_;

    my $app = $self->get_app;
    my %args = (
	login => $app->cache->get('login'), 
	password => $app->cache->get('password'),
	sid => $app->cache->get('sid'),
	url => $app->cache->get('ws'),
	ua =>  $app->cache->get('ua'));

    my ($sid,$login,$password,$url,$ua) = 
	@args{qw(sid login password url ua)};

    my %credentials = defined $sid ? (sid => $sid) : 
	( login => $login, password => $password );

    for my $k (keys %$query)
    {
	my $v = $query->{$k};
	$query->{$k} = ref($v) ? 
	    encode_json($v) : $v;
    }

    $url->query(%$query,%credentials);

    my $res = {}; 
    my $on_message_cb =
	sub {my ($tx, $msg) = @_; 
	     
	     $res = decode_json($msg);
	     if ($res->{status} eq 1000)
	     {  
		 my $total = $res->{total_size} // 0;
		 my $partial = $res->{copy_size} // 0;
		 my $percentage = ($partial * 100) / $total;
		 print STDERR "\r";
		 printf STDERR '%.2f%%', $percentage;
		 $tx->send('Ale');
	     }
	     else
	     {
		 print STDERR "\r";
		 $tx->finish;
	     }};

    $ua->websocket("$url" =>  sub { my ($ua, $tx) = @_;
				    $tx->on(message => $on_message_cb); $tx->send('Ale');} );

    Mojo::IOLoop->start;
    Mojo::Message::Response->new(json => $res);
}

sub print_filters
{
    my ($self,$parsing) = @_;
    my @f = sort keys %{$FILTERS->{$parsing->qvd_object}};
    print join "\n", @f;
}

sub print_arguments
{
    my ($self,$parsing) = @_;
    my @a = sort keys %{$ARGUMENTS->{$parsing->qvd_object}};
    print join "\n", @a;
}

sub print_order
{
    my ($self,$parsing) = @_;
    my @o = sort keys %{$ORDER->{$parsing->qvd_object}};
    print join "\n", @o;
}

sub print_fields
{
    my ($self,$parsing) = @_;
    my @f = sort @{$DEFAULT_FIELDS->{$parsing->qvd_object}};
   print join "\n",@f; 
}

sub get_action
{
    my ($self,$parsing) = @_;
    return eval { 
	$CLI_CMD2API_ACTION->{$parsing->qvd_object}->{$parsing->command} 
    } // die "No API action available"; 
}

sub get_all_ids_action
{
    my ($self,$parsing) = @_;
    return eval { 
	$CLI_CMD2API_ACTION->{$parsing->qvd_object}->{'ids'} 
    } // die "No API action available"; 
}

sub get_filters
{
    my ($self,$parsing) = @_;
    my $filters = $parsing->filters // {};

    for my $k ($parsing->filters->list_filters)
    {
	my $normalized_k = $FILTERS->{$parsing->qvd_object}->{$k} // $k;

	for my $ref_v ($parsing->filters->get_filter_ref_value($k))
	{
	    my $op = $parsing->filters->get_operator($ref_v);
	    my $v = $parsing->filters->get_value($ref_v);
	    $v = $self->get_value($parsing,$k,$v,'filter');

	    $parsing->filters->set_filter($ref_v,$normalized_k, {$op => $v});
	}
    }
    $parsing->filters->hash;
}

sub get_arguments
{
    my ($self,$parsing) = @_;
    my $arguments = $parsing->arguments // {};
    my $out = {};

    while (my ($k,$v) = each %$arguments)
    {
	my $normalized_k = $ARGUMENTS->{$parsing->qvd_object}->{$k} // $k;
	$v = $self->get_value($parsing,$k,$v,'argument');
	$out->{$normalized_k} = $v;
    }

    $out;
}

sub superadmin
{
    my $self = shift;
    my $app = $self->get_app;
    $app->cache->get('tid') ? return 1 : return 0;
}

sub get_order
{
    my ($self,$parsing) = @_;

    my $order = $parsing->order // {};
    my $out = [];
    my $criteria = $order->{field} // []; 

    for my $criteria (@$criteria)
    {
	$criteria = eval { $ORDER->{$parsing->qvd_object}->{$criteria} } // $criteria;
	push @$out, $criteria;
    }
    my $direction = $order->{order} // '-asc';
    { order => $direction, field => $out };
}

sub get_fields
{
    my ($self,$parsing,$api_res) = @_;

    my $rows = $api_res->json('/rows') // return ();
    my $first = $$rows[0] // return ();
    return qw(id) if $parsing->command eq 'create';
    return qw() unless $parsing->command eq 'get';

    my @asked_fields = @{$parsing->fields} ? 
	@{$parsing->fields}  : @{$DEFAULT_FIELDS->{$parsing->qvd_object}};

    my @retrieved_fields;
    for my $asked_field (@asked_fields)
    {
	my $api_field = eval {
	    $FIELDS->{$parsing->qvd_object}->{$asked_field} 
	} // $asked_field;

	push @retrieved_fields, $asked_field
	    if exists $first->{$api_field};
    } 
    @retrieved_fields;
}


sub get_fields_for_api
{
    my ($self,$parsing,$api_res) = @_;

    my @asked_fields = @{$parsing->fields};
    for my $asked_field (@asked_fields)
    {
	$asked_field = eval {
	    $FIELDS->{$parsing->qvd_object}->{$asked_field} 
	} // $asked_field;
    } 
    \@asked_fields;
}

sub get_field_value
{
    my ($self,$parsing,$api_res_obj,$cli_field) = @_;

    my $api_field = eval { $FIELDS->{$parsing->qvd_object}->{$cli_field} } // $cli_field;
    my $v = $api_res_obj->{$api_field};

    if (ref($v)) 
    {
	my $cb = eval { $FIELDS_CBS->{$parsing->qvd_object}->{$cli_field} }
	// die "No method available to parse complex field in API output";
	$v = $cb->($v);
    }

    return $v;
}

sub get_value
{
    my ($self,$parsing,$key,$value,$filter_or_argument) = @_;

    if ( my $cb = eval { $CBS_TO_GET_RELATED_OBJECTS_IDS->{$parsing->qvd_object}->{$filter_or_argument}->{$key}})
    {
	$value = $cb->($self,$value,$self->tenant_scoop);
	die "Unknown related object $key in filters" unless defined $$value[0];

	if ($filter_or_argument eq 'argument')
	{ 
	    die 'Amgiguous reference to object in filters' if 
		defined $$value[1];	    
	    $value = shift @$value;
	}
    }
    $value;
}

sub tenant_scoop
{
    my ($self,$tenant_scoop) = @_;

    $self->{tenant_scoop} = $tenant_scoop
	if $tenant_scoop;

    unless ($self->{tenant_scoop})
    {
	my $app = $self->get_app;
	$self->{tenant_scoop} = $app->cache->get('tid');
    }

    $self->{tenant_scoop};
}

1;
