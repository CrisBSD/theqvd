package QVD::DB::Result::VM_Cmd;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('vm_cmds');
__PACKAGE__->add_columns(
	name => {
	    data_type => 'varchar(20)'
	}
	);
__PACKAGE__->set_primary_key('name');
__PACKAGE__->has_many(runtime => 'QVD::DB::Result::VM_Runtime', 'vm_cmd');

sub get_has_many { qw(runtime); }
sub get_has_one { qw(); }
sub get_belongs_to { qw(); }


1;
