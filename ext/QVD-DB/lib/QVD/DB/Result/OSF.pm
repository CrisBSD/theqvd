package QVD::DB::Result::OSF;
use base qw/DBIx::Class/;

use strict;
use warnings;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('osfs');
__PACKAGE__->add_columns( tenant_id      => { data_type         => 'integer' },
			  id          => { data_type => 'integer',
                                           is_auto_increment => 1 },
                          name        => { data_type => 'varchar(64)' },
                          memory      => { data_type => 'integer' },
                          use_overlay => { data_type => 'boolean' },
                          user_storage_size => { data_type => 'integer',
                                                 is_nullable => 1 } );

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint(['name']);
__PACKAGE__->belongs_to(tenant => 'QVD::DB::Result::Tenant',  'tenant_id', { cascade_delete => 0 });
__PACKAGE__->has_many(vms => 'QVD::DB::Result::VM', 'osf_id', { cascade_delete => 0 } );
__PACKAGE__->has_many(properties => 'QVD::DB::Result::OSF_Property',
                      'osf_id', { join_type => 'INNER' });
__PACKAGE__->has_many(dis => 'QVD::DB::Result::DI', 'osf_id', { cascade_delete => 0 } );

sub _dis_by_tag {
    my ($osf, $tag, $fixed) = @_;
    my %search = ('tags.tag' => $tag);
    $search{'tags.fixed'} = $fixed if defined $fixed;
    $osf->dis->search(\%search, {join => 'tags'});
}

sub di_by_tag {
    my ($osf, $tag, $fixed) = @_;
    my $first = $osf->_dis_by_tag($tag, $fixed)->first;
    # warn "$osf->di_by_tag($tag, ".($fixed//'<undef>').") => ".($first//'<undef>');
    $first;
}

sub delete_tag {
    my ($osf, $tag) = @_;
    if (my $di = $osf->di_by_tag($tag, 0)) {
        $di->delete_tag($tag);
        # warn "$osf->delete_tag($tag) => $di";
        return 1;
    }
    # warn "$osf->delete_tag($tag) => <undef>";
    return 0;
}

sub get_has_many { qw(properties dis vms); }
sub get_has_one { qw(); }
sub get_belongs_to { qw(); }

1;
