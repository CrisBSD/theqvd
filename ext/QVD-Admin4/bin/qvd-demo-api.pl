#!/usr/lib/qvd/bin/perl
use strict;
use warnings;
use Mojolicious::Lite;
use Deep::Encode;
use Backticks;

my $perl_path = "$^X";
my $create_tenant_script_path = "./QVD-Admin4/bin/demo_tenant_creator.pl";

# Set port
app->config(hypnotoad => {listen => ['http://localhost:3001']});

sub get_input_json {
	my $c = shift;
	my $json = $c->req->json // $c->req->params->to_hash;

	deep_utf8_decode($json);

	return $json;
}

# Routes
any [qw(POST GET)] => '/create_tenant' => sub {
	my $c = shift;
	my $exit_code = 0;
	my $message = "OK";
	my $tenant_name = "";

	# Get parameters from url
	my $input_json = get_input_json($c);
	my @args = ();
	while(my ($key, $value) = each(%$input_json)){
		push @args, "-$key";
		push @args, $value;
	}

	# Call create tenant script
	my $cmd_output;
	eval {
		if(-e $create_tenant_script_path){
			my $cmd_call = "$perl_path $create_tenant_script_path " . join (" ", @args);
			$cmd_output = `$cmd_call`;
		} else {
			die "Tenant creator script does not exist";
		}
	};
	if ($@) {
		$message = $@;
		$exit_code = 1;
	} else {
		$exit_code = $cmd_output->exitcode();
		my $output = $cmd_output->stdout();
		chomp($output);
		my $OK_code = 0;
		if($OK_code == $exit_code){
			$tenant_name = $output;
		} else {
			$tenant_name = "";
			$message = $output;
		}
	}

	# Return state
	my $json = {
		status => $exit_code,
		message => $message,
		tenant => $tenant_name,
	};

	$c->render(json => $json);
};

app->start;
