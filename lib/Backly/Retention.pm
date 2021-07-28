package Backly::Retention;

=head1 OVERVIEW

Backly::Retenion - Utilities for managing long term retention of snapshots

=cut

use strict;
use warnings;

use POSIX qw(floor);
use DateTime;

use Exporter qw(import);
our @EXPORT_OK = qw(
  compute_retained
);

# Dispatch table which maps from RETENTION_INTERVALS to a function of the type:
# ($snapshots, $limit) => $buckets
my %RETENTION_INTERVALS = (
	all         => sub { _bucket_by_all(@_) },
	hourly      => sub { _bucket_by_prefix(@_, 'yyyymmdd_hh') },
	daily       => sub { _bucket_by_prefix(@_, 'yyyymmdd'   ) },
	monthly     => sub { _bucket_by_prefix(@_, 'yyyymm'     ) },
	yearly      => sub { _bucket_by_prefix(@_, 'yyyy'       ) },
	weekly      => sub { _bucket_by_week(@_) },
);

=head1 METHODS

=over 4

=item C<compute_retained>

Given a list of backup snapshots, and a retention config, returns filtered list of
snapshots which should still be retained

- snap_names - Arrayref of strings representing snapshot names to test
- retention  - Hashref retention config mapping interval names (eg, "hourly") to the number
               of snapshots to keep under that interval

=cut
sub compute_retained {
	my ($snap_names, $retention) = @_;

	my %snapshots = ();
	$snapshots{$_} = _parse_dt($_) foreach (@$snap_names);

  my @groups = ();
	foreach my $intervalName (keys(%$retention)) {
		my $intervalFn = $RETENTION_INTERVALS{$intervalName};
		die "Invalid retention interval $intervalName" unless $intervalFn;
		push @groups, {
			buckets => $intervalFn->(\%snapshots, $retention->{$intervalName}),
		};
	}

	# go through group and keep oldest from each bucket, storing in hash to de-dupe when we want to
	# keep the same snapshot due to multiple retention intervals
	my %kept = ();
	foreach my $group (@groups) {
		foreach my $bucket (@{$group->{buckets}}) {
			# find oldest non-failed run
			my $found = 0;
			foreach my $snap (@${bucket}) {
				if($snap !~ /-failed/) {
					$kept{$snap} = 1;
					$found = 1;
				  last;
				}
			}

			# fallback to whatever the oldest is
			$kept{$bucket->[0]} = 1 unless $found;
		}
	}

	my @keptNames = keys %kept;
	return \@keptNames;
}

# Helper which groups a set of snapshots into buckets based on common prefixes
# of the length given by $prefix
sub _bucket_by_prefix {
	my ($snapshots, $limit, $prefix) = @_;

	my %buckets = ();

	my $prefix_length = length($prefix);

	# do grouping
  foreach my $snap_name (keys %$snapshots) {
		my $bucket = substr $snap_name, 0, $prefix_length;
		$buckets{$bucket} //= [];
		push @{$buckets{$bucket}}, $snap_name;
	}

	return _post_process_buckets($limit, %buckets);
}

# Helper which buckets snapshots by each Mon-Sun week
sub _bucket_by_week {
	my ($snapshots, $limit) = @_;

	my %buckets = ();

	# do grouping
  foreach my $snap_name (keys %$snapshots) {
		my $snap_dt = $snapshots->{$snap_name};
		my $dow  = $snap_dt->day_of_week();
		my $wkId = floor($snap_dt->epoch() / (86400 * 7));

		# jan 01 1970 is a thursday, if $dow is > thursday, we're in the previous logical Mon-Sun week
		my $bucket = $dow > 4 ? $wkId - 1 : $wkId;

		$buckets{$bucket} //= [];
		push @{$buckets{$bucket}}, $snap_name;
	}

	return _post_process_buckets($limit, %buckets);
}

# Helper which generates bucket per snapshot (in order to keep them all)
sub _bucket_by_all {
	my ($snapshots, $limit) = @_;

	my %buckets = ();
	$buckets{$_} = [$_] foreach (keys %$snapshots);

	return _post_process_buckets($limit, %buckets);
}

# Given a hash of buckets, sorts the entries into order from oldest to newest,
# and limits to just the most recent $limit buckets
sub _post_process_buckets {
	my ($limit, %buckets) = @_;

	# ensure each bucket is in order from oldest to newest
	foreach my $k (keys %buckets) {
		@{$buckets{$k}} = sort @{$buckets{$k}}
	}

	# keep only the $limit most recent buckets
	my @results = keys %buckets;
	@results = sort { $b cmp $a } @results;
	@results = grep { defined $_ } @results[0..$limit-1]; # limit to n most recent
	@results = map  { $buckets{$_} } @results; # map from bucket names to items array

	return \@results;
}

# Parses a snapshot name to get DateTime
sub _parse_dt {
	my ($dt_str) = @_;
	$dt_str =~ /^(\d{4})(1[0-2]|0[0-9])(3[0-1]|[0-2][0-9])_(2[0-3]|[0-1][0-9])([0-5][0-9])/;
	my ($year,$month,$day,$hour,$minute) = ($1,$2,$3,$4,$5);
	die "Failed to parse snapshot datetime from '$dt_str'" unless defined $1 and defined $5;

	return DateTime->new(year => $year, month => $month, day => $day, hour => $hour, minute => $minute);
}

# Formats a DateTime to get a snapshot name
sub _format_dt {
	my ($dt) = @_;
	return $dt->strftime("%Y%m%d_%H%M");
}

=back

=cut

1;
