#!/usr/bin/perl -Ilib/

use strict;
use warnings;

use YAML qw(LoadFile);
use Getopt::Long::Descriptive qw(describe_options);
use Try::Tiny;
use Module::Load;

use Data::Dumper;

my ($opts, $usaget) = describe_options(
	'rbackup-filesystem %o',
	[ 'config|c=s',  'Path to config file describing what to backup', { required => 1 } ],
	[ 'host|h=s',    'Name of host to backup',                        { required => 1 } ],
	[ 'target|t=s',  'Target directory into which the backup should be written', { required => 1 } ],
);

exit main();

sub main {

	my $config = _load_config();

	my $failed = 0;

	for my $task (@$config) {
		my $pkg = "Rbackup::Task::" . ucfirst($task->{type});
		try {
		 	load ($pkg);
		} catch {
			print STDERR "No such task type: $task->{type}: $_";
		 	$failed = 1;
		};

		try {
			$pkg->run($opts, $task);
		} catch {
			print STDERR $_;
			$failed = 1;
		}
	}

	return $failed;
}

sub _load_config {
	my $config = [];
	if ( -f $opts->{config}) {
		print "Loading file $opts->{config}\n";
	  return [ LoadFile($opts->{config}) ];
	}

	if( -d $opts->{config}) {
		my $config = [];

		opendir (my $dh, $opts->{config});
		foreach my $f (readdir($dh)) {
			next unless $f =~ /\.yaml$/;

			print "Loading file $opts->{config}/$f\n";

			push @$config, $_ foreach LoadFile("$opts->{config}/$f");
		}
		closedir($dh);

		return $config;
	}

	print STDERR "Specified config path '$opts->{config}' does not exist\n";
	exit 1;
}
