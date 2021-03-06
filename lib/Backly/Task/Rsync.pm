package Backly::Task::Rsync;

=head1 OVERVIEW C<rsync>

Backup task which rsyncs data from source server to backup server

=cut

use strict;
use warnings;

use File::Path qw(make_path);
use File::Temp qw(tempfile);

use Exporter qw(import);
our @EXPORT_OK = qw(backup);

=head1 TASK PARAMETERS

=over 4

=item C<root>

Mandatory root file path location to rsync form

=item C<include>

Array of rsync --include patterns

Note that unlike plain rsync, we automatically generate all prefixes of the --include
pattern, eg, a/b/persistant would be skipped if we had the patterns:
+ **/persistant
- *
Since the global exclude * prevents recursion down through a/ and b/

=item C<exclude>

Array of rsync --exclude patterns

=back

=head1 FUNCTIONS

=over 4

=item C<backup>

Implementation of rsync backup task

=cut
sub backup {
	my ($pkg, $config, $destination, $task) = @_;

	my ($fh, $task_list) = tempfile("backly-rsync-XXXXXX", dir => '/tmp');
	print $fh _build_rsync_patterns($task->{include} // [], $task->{exclude} // []);
	close $fh;

	my $cmd = '/usr/bin/sudo /usr/bin/rsync -rz';
	if($config->{ssh}{key_path}){
		$cmd .= qq{ -e '/usr/bin/ssh -i "$config->{ssh}{key_path}"' };
	}

	my $ssh_str = $task->{host} . ':' . $task->{root} . '/';
	$ssh_str .= '/' unless $ssh_str =~ m|/$|;
	$ssh_str = $config->{ssh}{user} . '@' . $ssh_str if $config->{ssh}{user} and $task->{host} !~ /@/;

	my $targetDir = "${destination}$task->{root}";
	make_path($targetDir);

	$cmd .= qq {
      --rsync-path='/usr/bin/sudo /usr/bin/rsync'
      --perms --times
      --links
      -og --numeric-ids
      --delete-after
      --progress -h
      --include-from=${task_list}
      ${ssh_str} ${targetDir}
  };
	$cmd =~ s/\n//g;

	print "Performing rsync of ${ssh_str}...\n";
	qx{$cmd};
	die "Rsync failed, exit: $?" unless $? == 0;
	print "Rsync complete\n";

	unlink $task_list;
	return 0;
}

=item C<_build_rsync_patterns>

Generates the rsync include and exclude patterns given a list of includes and excludes

Imagine a pattern such as /*/persistent/** - IE: backup everything in
persistent directories that are the children of any directory within the root
directory

Eg, in the directory structure

appdata/
- gitlab/:
  - cache/
  - persistent/  <-- we want this
- registry/:
  - cache/
  - persistent/  <-- and this

If we just nievely add the patterns:
+ /*/persistent/**
- *

Then rsync wont do anything, since the root's children gitlab/ and registry/
would be rejected by the - * pattern

Instead we need the patterns:
+ /*/              --> look inside every directory within root
+ /*/persistent/   --> look inside the persistent directory within those
+ /*/persistent/** --> backup everything within those directories

We generate these automatically by splitting the strings in source_patterns

=cut
sub _build_rsync_patterns {

	my ($include, $exclude) = @_;

	my @to_include;
	foreach my $pattern (@$include) {
		my $prefix = '';
		foreach my $part (split('/', $pattern)) {
			next unless $part;
			$prefix = "${prefix}/${part}";
			push @to_include, $prefix;
		}
	}

	my $result = '';

	if (@to_include) {
		$result .= "+ $_\n" foreach @to_include;

		if(@$exclude){
			$result .= "- $_\n" foreach @$exclude;
		} else {
			$result .= "- *\n"; # exclude everything else
		}
	} elsif(@$exclude) {
		$result .= "- $_\n" foreach @$exclude;
		$result .= "+ *\n";
	} else {
		$result .= "+ *\n";
	}

	return $result;

}

=back

=cut

1;
