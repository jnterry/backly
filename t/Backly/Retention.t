#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 17;
use Test::Deep qw(cmp_set);
use List::MoreUtils qw(uniq);

require_ok('Backly::Retention');

use Backly::Retention qw(compute_retained);

# ------------------------------------------------------
# - TEST: Hourly Snapshots                             -
# ------------------------------------------------------
{
	my @snaps = qw(
  	20200102_0000
		20200101_1200
		20200101_0600
		20200101_0500
		20200101_0400
		20200101_0000
	);

  cmp_set(compute_retained(\@snaps, { hourly  => 10 }), \@snaps,             'hourly-keep-all');
	cmp_set(compute_retained(\@snaps, { hourly  =>  5 }), [@snaps[0..4]],      'hourly-keep-recent5');
	cmp_set(compute_retained(\@snaps, { hourly  =>  3 }), [@snaps[0..2]],      'hourly-keep-recent3');
	cmp_set(compute_retained(\@snaps, { monthly =>  1 }), [qw(20200101_0000)], 'hourly-keep-month');
	cmp_set(compute_retained(\@snaps, { yearly  =>  1 }), [qw(20200101_0000)], 'hourly-keep-year');
}

# ------------------------------------------------------
# - TEST: Longer term Snapshots and multiple groups    -
# ------------------------------------------------------
{
	my @snaps = qw(
  	20201201_1000
		20201201_0900
		20201201_0800
		20201201_0700

		20201120_0000

		20201110_0000

  	20201101_1000
		20201101_0900
		20201101_0800
		20201101_0700

		20201001_0000

		20200901_0000
		20200801_0000

		20200101_0500

		20190101_0000
		20180101_0000
		20170101_0000
		20160101_0000
  );

	my @hourly3  = @snaps[0..2];
	my @weekly4  = qw(20201201_0700 20201120_0000 20201110_0000 20201101_0700);
	my @monthly4 = qw(20201201_0700 20201101_0700 20201001_0000 20200901_0000);
	my @yearly4  = qw(20200101_0500 20190101_0000 20180101_0000 20170101_0000);

  cmp_set(compute_retained(\@snaps, { hourly   =>  3 }), \@hourly3,  'multi-keep-hourly3');
	cmp_set(compute_retained(\@snaps, { weekly   =>  4 }), \@weekly4,  'multi-keep-weekly4');
	cmp_set(compute_retained(\@snaps, { monthly  =>  4 }), \@monthly4, 'multi-keep-monthly4');
	cmp_set(compute_retained(\@snaps, { yearly   =>  4 }), \@yearly4,  'multi-keep-yearly4');

	cmp_set(compute_retained(\@snaps, { hourly => 3, weekly =>  4 }), [uniq(@hourly3, @weekly4)], 'multi-keep-hourly-and-weekly');
	cmp_set(compute_retained(\@snaps, { hourly => 3, yearly =>  4 }), [uniq(@hourly3, @yearly4)], 'multi-keep-hourly-and-yearly');
	cmp_set(
		compute_retained(\@snaps, { hourly => 3, weekly => 4, monthly => 4, yearly => 4 }),
		[uniq(@hourly3, @weekly4, @monthly4, @yearly4)],
		'multi-keep-all-periods'
	);
}

# ------------------------------------------------------
# - TEST: Simulate retried backup and 'all' period     -
# ------------------------------------------------------
{
	my @snaps = qw(
  	20201201_1000-3
		20201201_1000-2
		20201201_1000
		20201201_0900
  );

	my @hourly3 = qw(20201201_1000 20201201_0900);
	my @all3    = qw(20201201_1000-3 20201201_1000-2 20201201_1000);

  cmp_set(compute_retained(\@snaps, { hourly =>  3          }), \@hourly3,               'retries-keep-hourly');
	cmp_set(compute_retained(\@snaps, { all    =>  3          }), \@all3,                  'retries-keep-all');
	cmp_set(compute_retained(\@snaps, { all => 3, hourly => 3 }), [uniq(@hourly3, @all3)], 'retries-keep-multiple');
}

# ------------------------------------------------------
# - TEST: Ensure non-failed runs are kept preferentially
# ------------------------------------------------------
{
	my @snaps = qw(
		20201201_1010
		20201201_1005
  	20201201_1000-failed

		20201201_0910-failed
		20201201_0905-failed
		20201201_0900-failed

		20201201_0810-failed
		20201201_0805
		20201201_0800
  );

	my @hourly3 = qw(20201201_1005 20201201_0900-failed 20201201_0800);

	cmp_set(compute_retained(\@snaps, { hourly =>  3 }), \@hourly3, 'failed-keep-hourly');
}
