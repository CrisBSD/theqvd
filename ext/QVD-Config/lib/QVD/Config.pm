package QVD::Config;

our $VERSION = '0.01';

use warnings;
use strict;

use Config::Properties;
use QVD::Config::Defaults;

use Exporter qw(import);
our @EXPORT = qw(core_cfg core_cfg_all core_cfg_keys cfg ssl_cfg);

our $USE_DB //= 1;
our @FILES;
push @FILES, '/etc/qvd/node.conf' unless @FILES;

my $core_cfg = $QVD::Config::defaults;

for my $FILE (@FILES) {
    open my $cfg_fh, '<', $FILE or next;
    $core_cfg = Config::Properties->new($core_cfg);
    $core_cfg->load($cfg_fh);
    close $cfg_fh;
}

sub core_cfg {
    my $value = $core_cfg->requireProperty(@_);
    $value =~ s/\$\{(.*?)\}/core_cfg($1)/ge;
    $value;
}

sub core_cfg_all {
    map { $_ => core_cfg($_) } $core_cfg->propertyNames
}

sub core_cfg_keys { $core_cfg->propertyNames }

my $cfg;

sub reload {
    if ($USE_DB) {
	# we load the database module on demand in order to avoid circular
	# dependencies
	require QVD::DB::Simple;
	$cfg = { map { $_->key => $_->value } QVD::DB::Simple::rs('Config')->all }
    }
}

sub cfg {
    if ($USE_DB) {
	my $key = shift;
	if ($key =~ /^l7r\.ssl\./) {
	    # SSL keys are only loaded on demand.
	    require QVD::DB::Simple;
	    my $slot = QVD::DB::Simple::rs('SSL_Config')->search({ key => $key })->first;
	    return $slot->value if defined $slot;
	}
	$cfg // reload;
	my $value = $cfg->{$key} // $core_cfg->getProperty($key, @_) //
	    die "Configuration entry for $key missing\n";
	$value =~ s/\$\{(.*?)\}/cfg($1)/ge;
	$value;
    }
    else {
	goto &core_cfg;
    }
}

1;

__END__

=head1 NAME

QVD::Config - Retrieve QVD configuration from database.

=head1 SYNOPSIS

This module encapsulate configuration access.

    use QVD::Config;
    my $foo = cfg('field');
    my $bar = cfg('bar', $default_bar);

=head1 DESCRIPTION

FIXME Write the description

=head2 FUNCTIONS

=over

=item cfg($key)

=item cfg($key, $default)

Returns the configuration associated to the given key.

If no entry exist on the database it returns the default value if
given or otherwise undef.

=item core_cfg($key)

=item core_cfg($key, $default)

Returns configuration entries from the local file config.ini

Mostly used to configure database access and bootstrap the configuration system.

=back

=head1 AUTHORS

Hugo Cornejo (hcornejo at qindel.com)

Salvador FandiE<ntilde>o (sfandino@yahoo.com)

=head1 COPYRIGHT

Copyright 2009-2010 by Qindel Formacion y Servicios S.L.

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU GPL version 3 as published by the Free
Software Foundation.
