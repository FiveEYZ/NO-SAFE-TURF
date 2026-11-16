# Operations, backup and recovery

txAdmin runs nst_database_config, oxmysql 2.14.3 and no_safe_turf. Console-only nst_db_status checks storage initialization; nst_status reports gameplay state. No Python service, HTTP storage listener or cron task is needed.

## Backup is required before wipe

Set nst_backup_directory "server-backups" before starting the resource. Only a simple private directory name inside no_safe_turf is accepted; client/server/shared/web/node_modules names are forbidden. The runtime creates that directory when needed. Upgrades must preserve it. Never add it to manifest files or publish it. Files are excluded from release packaging independently of directory name.

With the metadata row locked, the backend reads the complete pre-wipe snapshot, persistent tables and required historical backups; inserts a hashed logical backup; reads it back and validates the payload; writes a uniquely named archive file; fsyncs, renames and reads it back byte-for-byte. Only then may seasonal reset statements run. File failure rolls back SQL and blocks the wipe. An overdue failed wipe also blocks economy commits. A transaction timeout can leave an extra valid pre-wipe archive; it must not result in a partial season.

This is a real, self-contained application backup outside MariaDB, not merely a backup row in the same database. It contains all nst_* application state represented by schema v1, including account/settings/history/ban records and prior referenced backups. It does not include database users/grants, txAdmin files, other resources or unrelated tables. Windows does not support directory fsync through this Node path; physical power-loss durability is untested. Configure off-host replication/provider backups and verify those separately.

If the hosting filesystem is read-only, storage is full or Cfx sandbox permissions deny the configured directory, automated destructive wipe is blocked. Fix and test that operational prerequisite; do not bypass the backup gate. Monitor disk capacity and archive retention manually; no automatic archive deletion is implemented.

## Seasons and administration

Default: Sunday 04:00 Europe/Stockholm. Weekday/hour/minute convars affect later calculations; saved deadlines survive restarts. Node Intl supplies time-zone rules. Update and retest the runtime after rule changes. Spring gaps move forward and autumn uses the first occurrence.

Warnings appear before a wipe. Commands are serialized during maintenance. Backup, ranking, seasonal reset, next deadline, revision, audit and wipe ledger commit together. Accounts, bans, settings and history survive. Repeated wipe keys do not reset twice. SQL admin/ban tables do not replace active ACE/txAdmin controls.

nst_wipe dryrun UNIQUE_KEY inspects without resetting. nst_wipe execute UNIQUE_KEY resets seasonal data. Use only on the explicitly intended database. During a storage failure, stop gameplay operations and recover persisted state; never manually replay a speculative snapshot.

## Export and restore without Python

Automatic archive files are directly usable. To export an existing database backup row to a new file:

    node tools/database.js export --config PRIVATE_JSON --id BACKUP_ID --file season.backup.json

To restore a verified archive, stop gameplay, prepare a different empty dedicated database and configure a separate private destination file:

    node tools/database.js init --config destination.private.json
    node tools/database.js restore --config destination.private.json --file season.backup.json --reschedule

The Node tools require Node 22+ on the administrator computer and the packaged resource/node_modules dependencies. The game host uses embedded Node. Restore checks hashes and references and refuses occupied tables. --reschedule chooses a future deadline; omitting it preserves an expired deadline that can immediately trigger another wipe. Inspect the destination before switching the server connection. Never restore over live player data.

Also use the provider's documented whole-database backup facility or MariaDB-native tooling under provider-approved grants. No universal provider backup mechanism is assumed or claimed tested.

## Administration integration

ACE group.admin receives nst.admin. The trusted server-local txAdmin playerHealed event persists death-state recovery and triggers in-place revive without refunding lost items/cash. Trusted kicks/shutdown avoid combat-logout penalties; actual death still applies. Ordinary disconnects during combat/robbery/raid/surrender retain penalties using the captured disconnect time. Teleport is not treated as cheating or fined; it can interrupt distance-based activities and custody remains enforced. NUI refuses to open over an already focused menu.

These behaviors pass mocks; actual txAdmin menu/native interaction must be tested in Enhanced. A consumed medkit may still be lost if the process dies after SQL commit but before the nonpersistent client heal effect.
