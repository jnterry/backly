# Overview

backly is a tool for remotely backing up systems accessible only over ssh

The tool is able to backup various kinds of resource, for example, file systems and databases using the appropriate tool (eg, rsync vs mysqldump).

The backup server must have a btrfs file system so that automatic copy-on-write snapshots can be taken of the data.

# Design Choices

Backly is designed to operate in a "pull over ssh" fashion - that is, a central backup server is allowed to ssh into the set of servers to be backed up, and pulls the data it requires.

All operations are performed via SSH.

While this "pull over ssh" model unlikely to be as scalable as all servers individually backing themselves up to external systems at their own pace, it does have a number of advantages:

- Minimal (no?) changes required on the servers to be backed up - as long as they have the ssh daemon running, backly will handle the rest
- Services (eg, database) available only on localhost of the target server don't need to be exposed further just for backups
- Data in transit is always encrypted, even when the underlying tool would not ordinarily do so
- If all servers were pushing, they would all be able to read the backups of every other server unless something complicated was done (eg, rsync user per server). This is a security problem, as one compromised server can read potentially sensitive data from all other servers on the network
