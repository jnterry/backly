package Backly::Task::Rsync;

use strict;
use warnings;

use File::Path qw(make_path);
use File::Temp qw(tempfile);

use Data::Dumper;

use Exporter qw(import);
our @EXPORT_OK = qw(
	run
);

sub backup {
	my ($pkg, $opts, $task) = @_;

	print "Running rsync task";
	print Dumper($opts);
	print Dumper($task);

	my $dest = "$opts->{target}/live/filesystem$task->{root}";
	make_path($dest);

	my ($fh, $task_list) = tempfile("rbackup-rsync-XXXXXX", dir => '/tmp');

	print $fh _build_rsync_patterns($task->{include} // [], $task->{exclude} // []);
	close $fh;

	my $cmd = '/usr/bin/sudo /usr/bin/rsync -rz';
	if($opts->{identity}){
		$cmd .= qq{ -e 'ssh -i "$opts->{identity}"' };
	}

	$cmd .= qq {
      --rsync-path='/usr/bin/sudo /usr/bin/rsync'
      --perms --times
      --links
      -og --numeric-ids
      --delete-after
      --progress -h
      --include-from=${task_list}
      $opts->{host}:$task->{root}/
      ${dest}
  };
	$cmd =~ s/\n//g;

	print "Performing rsync of $opts->{host}:$task->{root}...\n";
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