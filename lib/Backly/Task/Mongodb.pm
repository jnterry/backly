package Backly::Task::Mongodb;

=head1 OVERVIEW C<mongodb>

Backup task which uses mongo-dump to generate a snapshot of database

=cut

use strict;
use warnings;

use Backly::SshUtils qw(open_ssh);

use Exporter qw(import);
our @EXPORT_OK = qw(backup);

=head1 TASK PARAMETERS

=over 4

=item C<username>

Mongodb username to login as

=item C<password>

Mongodb password to login with

=item C<database>

Name of the database to backup

=item C<authenticationDatabase>

Which database contains the credentials for the user (defaults to C<database>)

=back

=head1 FUNCTIONS

=over 4

=item C<backup>

Implementation of mysql backup task

=cut
sub backup {
	my ($pkg, $config, $destination, $task) = @_;

	my $ssh = open_ssh($config, $task->{host});

	my $targetFile = "${destination}/$task->{database}.archive.gz";
	print "Dumping to $targetFile\n";

	my ($in, $out, $err) = $ssh->open_ex(
		{ stdin_discard => 1, stdout_file => $targetFile, stderr_pipe => 1 },
		'/usr/bin/mongodump',
		'-u', $task->{username},
		'-p', $task->{password},
		'--db', $task->{database},
		'--authenticationDatabase', ($task->{authenticationDatabase} || $task->{database} || 'admin'),
		'--archive', '--gzip', # write to single compressed file (on stdout - which we capture) rather than a bson file per collection
  );
	die "mongodump failed: " . $ssh->error if $ssh->error;

	# wait for process to complete -> $stderr has a log of what has been done
	print $_ while <$err>;

	die "mongodump failed: " . $ssh->error if $ssh->error;

	print "Completed mongodump of $task->{database}\n";

	return 0;
}

=back

=cut

1;
