# Upgrade and recovery guide

This guide applies to upgrades of NO SAFE TURF on an existing FiveM server. The current release is a prototype and the txAdmin recipe has not been run end to end. Validate every step in an isolated server profile and a separate empty MariaDB database before planning a live change.

## Before upgrading

1. Schedule a maintenance window and stop the NO SAFE TURF resource. Do not run two instances against the same database.
2. Record the current resource/package version, server artifact version, database server version, configuration paths, and enabled resources.
3. Preserve the existing `server.cfg`, private database connection configuration, txAdmin profile, server key, ACE assignments, and any custom resource files. Keep secrets out of Git, release archives, logs, and shared support material.
4. Make an independent database backup using the database provider's documented MariaDB tools. Store it outside both the live database and the NO SAFE TURF backup directory. Verify that the backup file is readable and arrange a restore rehearsal to a separate empty database.
5. Export NO SAFE TURF's application backup if the installed version supports it, and retain the archive unchanged. This application archive is not a replacement for a full database backup.
6. Review the release notes and schema migration instructions for the exact source and target versions. If no explicit migration is documented for that version pair, stop and seek a migration plan; do not infer compatibility from a matching table name or version number.

## Install and validate an upgrade candidate

1. Use a fresh server data directory and a newly created, empty test database. Never point the recipe or a migration command at the existing server database during rehearsal.
2. Install the candidate using its documented path. Preserve private configuration outside the package and reapply only reviewed settings; do not copy the old resource directory wholesale over the candidate.
3. Confirm schema version, resource health, adapter/connector version, and sanitized startup logs. Check that configuration does not expose credentials through replicated convars or client files.
4. Exercise basic gameplay, transactions, backup creation, and restore into another empty test database. Verify txAdmin ACE administration behavior and perform the documented two-client checks before considering a live upgrade.
5. Compare the tested configuration and migration steps with the intended server. Record the exact versions, backup identifiers, and validation results before scheduling any live work.

## Migration and rollback limits

There is no automatic destructive migration or live-data conversion authorized by this guide. Existing SQLite-era or other prior-format player data is not automatically migrated. The move to pinned oxmysql 2.14.3 must be validated against the exact release and schema before use; do not assume an adapter change itself upgrades data.

If a future release requires a schema change, use a versioned, documented migration that scopes every operation to NO SAFE TURF tables, checks the expected prior schema, and has a rehearsed rollback or restore procedure. Keep installation privileges separate from normal runtime privileges. Do not use `TRUNCATE`, broad database resets, or installer options that delete an existing database as an upgrade method.

For recovery, stop the resource and restore to a new empty destination database first. Validate the restored data and choose any season rescheduling explicitly. Switch configuration only after inspection and an approved maintenance decision. Do not overwrite or restore into the original database automatically.

No production upgrade, database restore, destructive migration, wipe, or deployment is performed by these instructions; those actions require the server owner's explicit approval and an individually reviewed change plan.
