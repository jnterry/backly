package Backly::Task::Mysql;

=head1 OVERVIEW C<mysql>

Backup task which uses mysqldump to generate a snapshot of database

=cut

use strict;
use warnings;

use Backly::SshUtils qw(open_ssh);

use Exporter qw(import);
our @EXPORT_OK = qw(backup);

=head1 TASK PARAMETERS

=over 4

=item C<username>

Mysql username to login as - must have SELECT privileges on target database

=item C<password>

Mysql password to login with

=item C<database>

Name of the database to backup

=back

=head1 FUNCTIONS

=over 4

=item C<backup>

Implementation of mysql backup task

=cut
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

=back

=cut

1;
