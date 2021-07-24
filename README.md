# Overview

`backly` is a tool for remotely backing up systems over ssh.

A central backup server should be setup with the `backly` tool installed, with a btrfs filesystem so that automatic copy-on-write snapshots can be taken of the data.

`backly` supports multiple types of resources using the appropriate tool installed on the to-be-backed-up server (eg, file systems via rsync, databases via mysqldump).

# Design Choices

## Overview

`backly` is designed to operate in a "pull over ssh" fashion - that is, a central backup server is allowed to ssh into the set of servers to be backed up, and pulls the data it requires.

All operations are performed via SSH.

While this "pull over ssh" model is unlikely to be as scalable as all servers individually backing themselves up to external systems at their own pace, and/or specific tools such as MySQL slave replication, it does have a number of advantages:

- Minimal changes required on the servers to be backed up - as long as they have the ssh daemon running with a user `backly` can use, `backly` will handle the rest
- Services (eg, databases) available only on localhost of the target server don't need to be exposed further just for backups
- Data in transit is always encrypted, even when the underlying tool would not ordinarily do so
- If all servers were pushing over SSH, they would all be able to read the backups of every other server unless something complicated was done (eg, rsync user per server). This is a security problem, as one compromised server can read potentially sensitive data from all other servers on the network

## Services and Tasks

`backly` groups jobs into high level "services", which each represent an individually managed set of point in time snapshots.

Each service may consist of multiple tasks, for example "rsync this directory", "dump this database", etc. Note that a service may consist of tasks which pull data from different physical machines.

This allows `backly` to produce semi-consistent views of an entire service, for example, a backup of a CMS may pull both assets from a file server, and meta data about those assets from a seperate database server.

These snapshots are "semi-consistent", since `backly` will perform all tasks within a service as close together as possible, but as tasks may take different amounts of time to complete, there could be minor discrepancies. This will be exacerbated if the target service only has eventual-consistency guarantees.

# Config

The root configuration for backly should be placed in `/etc/backly/backly.yaml` and be of the following form:

```yaml
# Root where backups are written - must be a btrfs filesystem for snapshots and diffs
destination: '/mnt/backup'

# Directory containing yaml files for each service to backup
services: '/etc/backly/services.d'

# SSH options
ssh:
  user: 'backly'                  # which user to SSH in as, defaults to undefined which will ssh in as the unix user running backly script
  key_path: '/etc/backly/key.rsa' # ssh keypath, defaults to undefined, which uses default ssh agent of unix user running backly script

# Default parameters for each task type
task_defaults:
  mysql:
    username: 'backups'
	password: 'backups'
```

Each service yaml should be of the form:

```yaml
name: 'cms'

tasks:
  - name: 'assets'
    type: 'rsync'
    host: 'cms-assets.example.com'
    # type specific config...
	root: '/mnt/cms
	include:
	  - 'assets/**'
  - name: 'meta'
    type: 'mysql'
	host: 'cms-db.example.com'
    # type specific config...
	database: 'cms'
```
