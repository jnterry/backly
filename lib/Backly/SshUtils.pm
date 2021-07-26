package Backly::SshUtils;

=head1 OVERVIEW

Backly::SshUtils - SSH utilities for Backly tool

=cut

use strict;
use warnings;

use Readonly;
use Net::OpenSSH;

use Exporter qw(import);
our @EXPORT_OK = qw(
  open_ssh
	ssh_dump_and_retrieve
);

# cache which maps 'user@host' strings to an $ssh object, to enable re-using connections
# between tasks
my %connectionCache = ();

=head1 METHODS

=over 4

=item C<open_ssh>

Estabilishes a new SSH connection to host given the Backly config

=cut
sub open_ssh {
	my ($config, $host) = @_;

	my $user = $config->{ssh}{user} || getlogin();

	my $cacheKey = $user . '@' . $host;
	return $connectionCache{$cacheKey} if $connectionCache{$cacheKey};

	my %params = (
		user => $user,
	);
	$params{key_path} = $config->{ssh}{key_path} if $config->{ssh}{key_path};

	print "Opening SSH Connection to $host\n";

	my $ssh = Net::OpenSSH->new($host, %params);
	$ssh->error and die "Failed to establish SSH connection to $host: " . $ssh->error;

	# run something so if we got a permission denied we will notice here, rather than on first
	# usage of $ssh object
	my $remoteUser = $ssh->capture('/usr/bin/whoami');
	chomp $remoteUser;
	die "Failed to establish SSH connection to $host: " . $ssh->error if $ssh->error;

	print "Connected to $host as $remoteUser\n";

	$connectionCache{$cacheKey} = $ssh;

	return $ssh;
}

=back

=cut

1;
