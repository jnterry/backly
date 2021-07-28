package Backly::Snapshot;

=head1 OVERVIEW

Backly::Retenion - Utilities for dealing with snapshots

=cut

use strict;
use warnings;

use File::Path qw(make_path);
use POSIX;

use Backly::Retention qw(compute_retained);

use Exporter qw(import);
our @EXPORT_OK = qw(
	create_live_volume
	create_snapshot
	delete_snapshot
	delete_old_snapshots
);

=head1 METHODS

=over 4

=item C<create_live_volume>

Creates live btrfs volume for service directory

=cut
sub create_live_volume {
	my ($serviceDir) = @_;
	make_path($serviceDir);

	my $liveDir = "$serviceDir/live";

	qx|/usr/bin/btrfs subvolume create $liveDir| unless (-d "$serviceDir/live");
	die "Failed to create live subvolume for $serviceDir, exit: $?" unless $? == 0;

	return $liveDir;
}

=item C<create_snapshot>

Makes a new snapshot of the current live state for given service directory

=cut
sub create_snapshot {

	my ($serviceDir, $success) = @_;

	# generate snapshot name
	my $timestamp = strftime "%Y%m%d_%H%M", localtime time;
	my $snapName = $timestamp . ($success ? '' : '-failed');

	print "Creating snapshot ${snapName}...\n";
	make_path("${serviceDir}/snapshots");
	my $snapPath = "${serviceDir}/snapshots/${snapName}";

	if(-d $snapPath) {
		my $i = 2;
		while(-d "${snapPath}-${i}") { ++$i; }
		$snapPath .= "-${i}";
		print "Found existing snapshot at intended path, will use $snapPath\n";
	}

	qx|/usr/bin/btrfs subvolume snapshot -r $serviceDir/live $snapPath|;
	die "Failed to create snapshot, exit: $?" unless $? == 0;

	print "Snapshot created at $snapPath\n";

	return $snapPath;
}

=item C<create_snapshot>

Deletes an existing snapshot specified by absolute path

=cut
sub delete_snapshot {
	my ($path) = @_;

	qx|/usr/bin/btrfs subvolume delete $path| if -d $path;
	die "Failed to delete snapshot $path, exit: $?" unless $? == 0;
}

=item C<delete_old_snapshots>

Deletes all old snapshots according to a retention config

=cut
sub delete_old_snapshots {
	my ($serviceDir, $retentionConfig) = @_;

	print "Checking for old snapshots to remove in $serviceDir\n";
	opendir(my $dh, "${serviceDir}/snapshots");
	my @snaps = grep { -d "${serviceDir}/snapshots/$_" and $_ !~ /\.\.?/ } readdir($dh);
	closedir($dh);

	unless(scalar @snaps) {
		print "No snapshots present, aborting cleanup";
		return 0;
	}

	my $toKeep = compute_retained(\@snaps, $retentionConfig);
	my %toDelete = ();
	$toDelete{$_} = 1    foreach @snaps;
	delete $toDelete{$_} foreach @$toKeep;

	my $toDeleteCount = scalar keys %toDelete;
	return 0 unless $toDeleteCount;
	my $keepCount = (scalar @snaps) - $toDeleteCount;
	die "Retention config would keep 0 snapshots - ignoring and keeping all" unless $keepCount;

	print "Found $toDeleteCount snapshots to remove (will keep $keepCount)\n";

	delete_snapshot("${serviceDir}/snapshots/$_") foreach keys %toDelete;

	return $toDeleteCount;
}

=back

=cut

1;
