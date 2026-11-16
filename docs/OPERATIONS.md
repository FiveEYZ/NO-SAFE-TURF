# Operations

txAdmin manages the resource and its embedded JavaScript storage adapter. Follow [MARIADB.md](MARIADB.md) for installation and offline backup commands. No Python process or HTTP storage service is needed.

## Health and recovery

Console-only nst_db_status checks initialization; nst_status reports game state. Database errors are sanitized. Check private JSON path, grants, network, MariaDB version and initialized schema if storage is unavailable. Restart the resource after editing the connection file.

Economic actions persist before client effects. Stale revisions are rejected. After an uncertain outcome, the adapter reloads persisted state. Do not manually replay snapshots or change revisions. A crash after medkit consumption commits but before the client heals can consume the item without healing.

Run one active gameplay resource per database. The global revision lock does not make shared gameplay horizontally scalable.

## Seasons

Default: Sunday 04:00 Europe/Stockholm, using embedded Node Intl time-zone data. Update the runtime and retest DST after updates. Spring gaps move forward; autumn uses the first occurrence. Saved deadlines survive restarts. Overdue seasons are processed when state loads.

nst_wipe dryrun UNIQUE_KEY inspects without resetting state. nst_wipe execute UNIQUE_KEY resets seasonal data. Both require console or ACE nst.admin. Repeating a completed key does not wipe again.

Pre-wipe backup, ranking, reset, next deadline, revision, audit and wipe ledger commit together. Accounts, bans, settings, backups, rankings and audit survive. SQL account/ban tables do not replace active ACE/txAdmin administration.

Export backups outside the database and test restoration to an empty destination. Stop the resource before recovery. Inspect restored state and decide explicitly whether to reschedule an expired deadline.

## Status

Local code and isolated databases have been tested. The deployment database has not been initialized or modified. Enhanced startup, real clients, physical power loss and load/endurance tests remain outstanding.

