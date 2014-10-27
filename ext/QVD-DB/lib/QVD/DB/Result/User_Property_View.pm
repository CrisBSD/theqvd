package QVD::DB::Result::User_Property_View;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('users_properties_view');
__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(

"SELECT me.id            as id, 
        properties.key   as key, 
        properties.value as value, 

 FROM      users me 
 LEFT JOIN user_properties properties ON(properties.user_id=me.id) 
 GROUP BY me.id, properties.key, properties.value"

);

__PACKAGE__->add_columns(
    'id' => {
	data_type => 'integer'
    },

    'key' => {
	data_type => 'varchar(64)',
    },

    'value' => {
	data_type => 'varchar(64)',
    },
    );

1;
