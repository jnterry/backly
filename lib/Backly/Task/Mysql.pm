package Backly::Task::Mysql;

use strict;
use warnings;

use File::Path qw(make_path);
use File::Temp qw(tempfile);

use Backly::SshUtils qw(open_ssh);

use Data::Dumper;

use Exporter qw(import);
our @EXPORT_OK = qw(backup);

sub backup {
	my ($pkg, $config, $destination, $task) = @_;

	my $ssh = open_ssh($config, $task->{host});

	my $targetFile = "${destination}/$task->{database}.sql";
	print "Dumping to $targetFile\n";

	my ($in, $out, $err) = $ssh->open_ex(
		{ stdin_discard => 1, stdout_file => $targetFile, stderr_pipe => 1 },
		'/usr/bin/mysqldump',
		'-u', $task->{username},
		'-p' . $task->{password},
		'--single-transaction=TRUE', # rather than using LOCK table, just ensure we run the entire dump in a tx (so other reads can continue)
		$task->{database}
	);
	die "Failed to start mysqldump process: " . $ssh->error if $ssh->error;

	# wait for process to complete, report any errors
	my $errOut = '';
	$errOut .= $_ while <$err>;
	die "Failed to complete mysqldump:\n $errOut" if length($errOut);

	die "Failed to start mysqldump process: " . $ssh->error if $ssh->error;

	print "Completed mysqldump of $task->{database}\n";

	return 0;
}

1;
