package QVD::DB::Result::DI;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('dis');
__PACKAGE__->add_columns( id     => { data_type => 'integer',
                                      is_auto_increment => 1 },
                          osf_id => { data_type => 'integer' },
                          blocked => { data_type         => 'boolean',
                                       default_value => 0 },

                          # Valor tomado de la variable PATH_MAX de
                          # /usr/src/linux-headers-2.6.28-15/include/linux/limits.h:

                          # TODO: rename "path" as "file"
                          path  => { data_type => 'varchar(4096)' },
                          version => { data_type => 'varchar(64)' },
 );

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(osf => 'QVD::DB::Result::OSF', 'osf_id', { cascade_delete => 0 } );
__PACKAGE__->has_many(properties => 'QVD::DB::Result::DI_Property', \&custom_join_condition, 
		      {join_type => 'LEFT', order_by => {'-asc' => 'key'}});

__PACKAGE__->has_many(vm_runtimes => 'QVD::DB::Result::VM_Runtime', 'current_di_id', { cascade_delete => 0 });
__PACKAGE__->has_many(tags => 'QVD::DB::Result::DI_Tag', 'di_id', { order_by => { '-desc' => 'tag' }});

__PACKAGE__->add_unique_constraint(['osf_id', 'version']);

######### Log info

__PACKAGE__->has_one(creation_log_entry => 'QVD::DB::Result::Wat_Log', 
		     \&creation_log_entry_join_condition, {join_type => 'LEFT'});

sub creation_log_entry_join_condition
{ 
    my $args = shift; 

    { "$args->{foreign_alias}.object_id" => { -ident => "$args->{self_alias}.id" },
      "$args->{foreign_alias}.qvd_object"     => { '=' => 'di' },
      "$args->{foreign_alias}.type_of_action"     => { '=' => 'create' } };
}

sub update_log_entry_join_condition
{ 
    my $args = shift; 

    my $sql = "IN (select id from wat_log where object_id=$args->{self_alias}.id and 
                   qvd_object='di' and type_of_action='update' order by id DESC LIMIT 1)";
    { "$args->{foreign_alias}.id"     => \$sql , };
}

###################

sub tag_list {
    my $di = shift;
    sort (map $_->tag, $di->tags);
}

sub has_tag {
    my ($di, $tag) = @_;
    my $ditag = $di->tags->search({tag => $tag})->first;
    return !!$ditag;
}

sub delete_tag {
    my $di = shift;
    my $tag = shift;
    my $ditag = $di->tags->search({tag => $tag})->first;
    $ditag->delete if $ditag;
}


sub tags_get_columns
{
    my $self = shift;
    [ sort { $a->{tag} cmp $b->{tag} }
      map { { $_->get_columns } } $self->tags ];
}

sub custom_join_condition
{ 
    my $args = shift; 
    my $key = $ENV{QVD_ADMIN4_CUSTOM_JOIN_CONDITION};

    { "$args->{foreign_alias}.di_id" => { -ident => "$args->{self_alias}.id" },
      "$args->{foreign_alias}.key"     => ($key ? { '=' => $key } : { -ident => "$args->{foreign_alias}.key"}) };
}

sub tenant_id
{
    my $self = shift;
    $self->osf->tenant_id;
}

sub tenant_name
{
    my $self = shift;
    $self->osf->tenant->name;
}

sub tenant
{
    my $self = shift;
    $self->osf->tenant;
}

sub get_properties_key_value
{
    my $self = shift;

    ( properties => { map {  $_->key => $_->value  } $self->properties->all });
} 

sub name
{
    my $self = shift;
    $self->path;
}

1;
