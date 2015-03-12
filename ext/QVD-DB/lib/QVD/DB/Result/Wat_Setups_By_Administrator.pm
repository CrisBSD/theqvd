package QVD::DB::Result::Wat_Setups_By_Administrator;
use base qw/DBIx::Class/;

use strict;
use warnings;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('wat_setups_by_administrators');
__PACKAGE__->add_columns( id          => { data_type => 'integer',
                                           is_auto_increment => 1 },
			  block      => { data_type         => 'integer',
                                          default_value     => 0 },
			  language      => { data_type         => 'varchar(64)',
                                             default_value => 'EN' },
                          administrator_id        => { data_type => 'integer' });

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint(['administrator_id']);
__PACKAGE__->belongs_to(administrator => 'QVD::DB::Result::Administrator', 'administrator_id');

1;
