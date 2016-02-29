package QVD::DB::Result::Views_Setup_Properties_Tenant;
use base qw/DBIx::Class/;

use strict;
use warnings;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('views_setups_properties_tenant');
__PACKAGE__->add_columns(
	id              => { data_type => 'integer', is_auto_increment => 1 },
	qvd_obj_prop_id => { data_type => 'integer' },
	visible         => { data_type => 'boolean' },
	view_type       => { data_type => 'administrator_and_tenant_views_setups_view_type_enum' },
	device_type     => { data_type => 'administrator_and_tenant_views_setups_device_type_enum' },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([qw(qvd_obj_prop_id view_type device_type)]);
__PACKAGE__->belongs_to(qvd_obj_prop => 'QVD::DB::Result::QVD_Object_Property_List', 'qvd_obj_prop_id');

sub tenant_id {
	my $self = shift;
	return $self->qvd_obj_prop->tenant_id;
}

sub tenant_name {
	my $self = shift;
	return $self->qvd_obj_prop->tenant_name;
}

sub key {
	my $self = shift;
	return $self->qvd_obj_prop->key;
}

sub qvd_object {
	my $self = shift;
	return $self->qvd_obj_prop->qvd_object;
}

1;