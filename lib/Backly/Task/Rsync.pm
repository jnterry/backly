package Backly::Task::Rsync;

use strict;
use warnings;

use File::Path qw(make_path);
use File::Temp qw(tempfile);

use Exporter qw(import);
our @EXPORT_OK = qw(backup);

sub backup {
	my ($pkg, $config, $destination, $task) = @_;

	my ($fh, $task_list) = tempfile("backly-rsync-XXXXXX", dir => '/tmp');
	print $fh _build_rsync_patterns($task->{include} // [], $task->{exclude} // []);
	close $fh;

	my $cmd = '/usr/bin/sudo /usr/bin/rsync -rz';
	if($config->{ssh}{key_path}){
		$cmd .= qq{ -e 'ssh -i "$config->{ssh}{key_path}"' };
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

	print "Performing rsync of $task->{host}:$task->{root}...\n";
	qx{$cmd};
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

1;
