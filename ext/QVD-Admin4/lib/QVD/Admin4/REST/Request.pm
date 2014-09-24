package QVD::Admin4::REST::Request;
use strict;
use warnings;
use Moose;
use QVD::Admin4::Exception;

has 'json_wrapper', is => 'ro', isa => 'QVD::Admin4::REST::JSON', required => 1;
has 'qvd_object_model', is => 'ro', isa => 'QVD::Admin4::REST::Model', required => 1;
has 'db_qvd_config_provider', is => 'ro', isa => QVD::Admin4::DBConfigProvider;
has 'modifiers', is => 'ro', isa => 'HashRef', default => sub { { distinct => 1, join => [], order_by = { '-asc' => []} }; };
has 'filters', is => 'ro', isa 'HashRef', default => sub { {}; };
has 'arguments', is => 'ro', isa 'HashRef', default => sub { {}; };
has 'related_objects_arguments', is => 'ro', isa 'HashRef', default => sub { {}; };
has 'nested_queries', is => 'ro', isa 'HashRef', default => sub { {}; };

my $ADMIN;

sub BUILD 
{
    my $self = shift;
    $ADMIN = $self->qvd_object_model->current_qvd_administrator;

    $self->forze_filtering_by_tenant;
    $self->forze_tenant_assignment_in_creation;
    $self->switch_custom_properties_json2request;

    $self->check_filters_validity_in_json;
    $self->check_arguments_validity_in_json;
    $self->check_nested_queries_validity_in_json;
    $self->check_order_by_validity_in_json;

    $self->set_pagination_in_request;
    $self->set_filters_in_request;
    $self->set_arguments_in_request;
    $self->set_nested_queries_in_request;
    $self->set_order_by_in_request;
}

sub action 
{
    my $self = shift;
    $self->json_wrapper->action;
}

sub table 
{
    my $self = shift;
    $self->qvd_object_model->qvd_object;
}

sub set_filter
{
    my ($self,$key,$val) = @_;
    $self->filters->{$key} = $value;
}

sub set_argument
{
    my ($self,$key,$val) = @_;
    $self->arguments->{$key} = $value;
}

sub set_nested_query
{
    my ($self,$key,$val) = @_;
    $self->nested_queries->{$key} = $value;
}

sub set_related_object_argument
{
    my ($self,$rel_object,$key,$val) = @_;
    $self->related_object_arguments->{$rel_object}->{$key} = $value;
}

sub add_to_join
{
    my ($self,$key) = @_;
    push @{$self->modifiers->{join}}, $key;
}

sub add_to_order_by
{
    my ($self,$key) = @_;
    my $order_criteria = $self->modifiers->{order_by}->{'-desc'} //
	$self->modifiers->{order_by}->{'-asc'};
    push @$order_criteria, $key;
}

sub set_pagination_in_request
{
    my $self = shift;
    $self->modifiers->{page} = $self->json_wrapper->offset // 1; 
    $self->modifiers->{rows}  = $self->json_wrapper->block // 10000; 
}

sub forze_filtering_by_tenant
{
    my $self = shift;
    return unless $self->qvd_object_model->available_filter('tenant_id');
    if ($self->json_wrapper->has_filter('tenant_id'))
    {
	return if $ADMIN->is_superadmin;
	$self->json_wrapper->forze_filter_deletion('tenant_id');
    }

    $self->set_filter('tenant_id',$ADMIN->tenant_scoop);
}

sub forze_tenant_assignment_in_creation
{
    my $self = shift;
	
    return if $ADMIN->is_superadmin; # It must be provided in the input
    return unless $self->qvd_object_model->mandatory_argument('tenant_id');

    $self->instantiate_argument('tenant_id',$ADMIN->tenant_id);
}

sub switch_custom_properties_json2request
{
    my $self = shift;
    my @custom_properties_keys = 
	$self->db_qvd_config_provider->
	get_custom_properties_keys($self->qvd_object_model->qvd_object);

    my $found_properties = 0;
    for my $property_key (@custom_properties_keys)
    {
	next unless $self->json_wrapper->has_filter($property_key);

	$found_properties++;
	my $property_value = self->json_wrapper->get_filter_value($property_key);
	$property_value = { like => "%".$property_value."%"};
	my $property_dbix_key = $found_properties > 1 ?
	    "properties_$found_properties" : 'properties';
	$self->json_wrapper->forze_filter_deletion($property_key);
        $self->set_filter($property_dbix_key,$property_value);
        $self->add_to_join('properties');
    }
}

sub check_filters_validity_in_json
{
    my $self = shift;

    $self->qvd_object_model->available_filter($_) || 
	QVD::Admin4::Exception->throw(code => 9)
	for $self->json_wrapper->filters_list;

    $self->json_wrapper->has_filter($_) ||
	QVD::Admin4::Exception->throw(code => 10)
	for $self->qvd_objec_model->mandatory_filters;
}

sub check_arguments_validity_in_json
{
    my $self = shift;

    if ($self->qvd_object_model->type_of_action eq 'update')
    {
	$self->qvd_object_model->available_argument($_) || 
	    QVD::Admin4::Exception->throw(code => 12)
	    for $self->json_wrapper->arguments_list;
    }

    if ($self->qvd_object_model->type_of_action eq 'create')
    {
	$self->json_wrapper->has_arguments($_) || 
	    $self->qvd_object_model->get_default_argument_value($_) ||
	    QVD::Admin4::Exception->throw(code => 23502)
	    for $self->qvd_object_model->mandatory_arguments;
    }
}

sub check_nested_queries_validity_in_json
{
    my $self = shift;
}

sub check_order_by_validity_in_json
{
    my $self = shift;
}

sub set_filters_in_request
{
    my $self = shift;
    for my $key ($self->json_wrapper->filters_list)
    {
	my $key_dbix_format = 
	    $self->qvd_object_model->map_filter_to_dbix_format($key);
	my $value = $self->json_wrapper->get_filter_value($key);
	my $value_normalized = $self->qvd_object_model->normalize_value($value);
	$value_normalized = { like => "%".$value_normalized."%"} 
	if $self->qvd_object_model->subchain_filter($key);
	$self->set_filter($key_dbix_format,$value_normalized);
    }
}


sub set_arguments_in_request
{
    my $self = shift;
    for my $key ($self->json_wrapper->arguments_list)
    {
	my $key_dbix_format = 
	    $self->qvd_object_model->map_argument_to_dbix_format($key);
	my $value = $self->json_wrapper->get_argument_value($key);
	my $value_normalized = $self->qvd_object_model->normalize_value($value);
	$self->instantiate_argument($key_dbix_format,$value_normalized);
    }
    $self->set_arguments_in_request_with_defaults;
}


sub set_arguments_in_request_with_defaults
{
    my $self = shift;

    for my $key ($self->qvd_object_model->mandatory_arguments)
    {
	next if $self->json_wrapper->has_arguments($key);
	my $key_dbix_format = 
	    $self->qvd_object_model->map_argument_to_dbix_format($key);
	my $value = $self->qvd_object_model->get_default_argument_value($key);
	$self->instantiate_argument($key_dbix_format,$value);
    }
}

sub instantiate_argument
{
    my ($self,$dbix_key,$value) = @_;
    $value = undef if $value eq '';
    # WARNING: Is this the right solution to all fields??

    my ($table,$column) = $dbix_key =~ /^(.+)\.(.+)$/;

    $table eq 'me'                                            ?
    $self->set_argument($column,$value)                       :
    $self->set_related_object_argument($table,$column,$value);
}


sub set_order_by_in_request
{
    my $self = shift;

    my $order_direction = $self->json_wrapper->order_direction // '-asc';
    my $order_criteria = $self->json_wrapper->order_criteria //
	$self->qvd_object_model->get_default_order_criteria;

    $self->modifiers->{order_by}->{'-desc'} =
	delete $self->modifiers->{order_by}->{'-asc'}
    if $order_direction eq '-desc';

    for my $order_criterium (@$order_criteria)
    {
	$self->add_to_order_by(
	    $self->qvd_object_model->map_argument_to_dbix_format($order_criterium));
    }
}

sub set_nested_queries_in_request
{
    my $self = shift;
    $self->{nested_queries} = $self->json_wrapper->nested_queries;
}

1;

