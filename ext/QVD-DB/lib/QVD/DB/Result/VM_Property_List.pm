package QVD::DB::Result::VM_Property_List;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('vm_properties_list');
__PACKAGE__->add_columns( property_id   => { data_type => 'integer' } );

__PACKAGE__->set_primary_key('property_id');
__PACKAGE__->has_many(properties => 'QVD::DB::Result::VM_Property', 'property_id', { cascade_delete => 0 });
__PACKAGE__->belongs_to(properties_list => 'QVD::DB::Result::Property_List', 'property_id');
__PACKAGE__->belongs_to(properties_list => 'QVD::DB::Result::Property_List', 'property_id');

sub tenant_name
{
    my $self = shift;
    $self->properties_list->tenant->name;
}

1;
