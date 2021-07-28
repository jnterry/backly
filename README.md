# Overview

`backly` is a dumb-but-simple tool for remotely backing up systems over ssh.

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

`backly` groups jobs into high level "services", each of which represents a logical bundle of data which can be backed up and restored in isolation. Backly manages an independent set of point-in-time snapshots for each service.

Each service may consist of multiple tasks, for example "rsync this directory", "dump this database", etc. Note that a service may consist of tasks which pull data from different physical machines.

This allows `backly` to produce semi-consistent views of an entire service, for example, a backup of a CMS may pull both assets from a file server, and meta data about those assets from a seperate database server.

These snapshots are "semi-consistent", since `backly` will perform all tasks within a service as temporally close together as possible, but since tasks may take different amounts of time to complete, there could be discrepancies. This will be exacerbated if the target service only has eventual-consistency guarantees.

# Config

## Global Config

The root configuration for backly is usually placed at `/etc/backly/backly.yaml` and should be of the following form:

```yaml
# Root where backups are written - must be a btrfs filesystem for snapshots and diffs
destination: '/mnt/backup'

# Directory containing yaml files describing task list for each service to backup
services: '/etc/backly/services.d'

# SSH options
ssh:
  user: 'backly'                  # which user to SSH in as, if undefined which will ssh in as the unix user running backly script
  key_path: '/etc/backly/key.rsa' # ssh keypath, if undefined, uses default ssh agent of unix user running backly script

# Default parameters for each task type - merged with the data in task definition
task_defaults:
  mysql:
    username: 'backups'
    password: 'backups'
```

## Service Config

Each service yaml should be of the form:

```yaml
name: 'cms' # name of the service, data will be written to subdirectory named after the service in global $destination variable

tasks:
  - name: 'assets'
    type: 'rsync'
    host: 'cms-assets.example.com'
    # type specific config (merged with corresponding task_defaults)
    root: '/mnt/cms
    include:
      - 'assets/**'
  - name: 'meta'
    type: 'mysql'
    host: 'cms-db.example.com'
    # type specific config (merged with corresponding task_defaults)
    database: 'cms'
```

A full list of "task types" and their corresponding parameters can be found by examining the contents of the [task directory](lib/Backly/Task) (use perldoc to view parameter docs for each task).

## Retention Config

A retention config is used to control which snapshots to keep, this can be placed in the service yaml file, under the key `retention`, or the global yaml file, under the key `default_retention` used by services with no specific `retention` config. If neither is specified, backly will not automatically delete old snapshots.

Retention works by grouping the snapshots into buckets of different interval sizes (hourly, weekly, etc), keeping snapshots from the n most recent buckets, and finding the oldest non-failed snapshot in each kept bucket.

Multiple intervals can be specified simultaneously, eg to keep the most recent hourly backups and the most recent daily backups.

The special interval `all` will not sort into buckets, and just keeps the n most recent backups.

```yaml
retention:
  all: 3
  hourly: 48
  daily: 14
  weekly: 12
  monthly: 12
  yearly: 3
```
