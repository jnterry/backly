package Backly::Config;

use strict;
use warnings;

use Readonly;
use YAML qw(LoadFile);

use Exporter qw(import);
our @EXPORT_OK = qw(
  load_config
);

sub load_config {
	my $path = $ENV{BACKLY_CONFIG} || '/etc/backly/backly.yaml';

	print "Loading config from $path\n";

	my $config = LoadFile($path);
	die "Config at $path must include 'destination' parameter" unless defined $config->{destination};

	return $config;
}


1;
