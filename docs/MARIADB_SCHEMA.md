# MariaDB storage contract

`database/mariadb/001_initial.sql` defines the initial NO SAFE TURF schema for a dedicated MariaDB 10.11+ database. Every table uses InnoDB and `utf8mb4_bin`. The migration creates missing tables and records version 1; it does not create a database/user, erase data, or initialize a season deadline. The runtime must insert the singleton `nst_meta` row with revision 0, season 1, its computed future wipe timestamp, and an empty JSON object for `extra` only when no row exists.

## State mapping

| API state | Table | Representation |
|---|---|---|
| `season`, envelope `revision` and `nextWipe` | `nst_meta` | One row with `id=1`; integers in dedicated columns |
| Other top-level fields such as `nextDrop` | `nst_meta.extra` | JSON object; excludes the seven entity collections and `season` |
| `players[id]` | `nst_players` | `entity_id`, JSON `payload` excluding `items` |
| `players[id].items[item]` | `nst_player_items` | `owner_id`, `item_id`, unsigned integer `quantity` |
| `gangs[id]` | `nst_gangs` | `entity_id`, JSON `payload` excluding `items` |
| `gangs[id].items[item]` | `nst_gang_items` | `owner_id`, `item_id`, unsigned integer `quantity` |
| `territories`, `robberies`, `hideouts`, `drops`, `alerts` | Corresponding `nst_` table | One `entity_id` and JSON `payload` per entity |

The adapter reconstructs the existing Lua state API on reads. Empty collections and inventories must become objects/maps, including when Lua JSON encoded an empty table as an array. Drop inventories remain in the drop payload. Cash, gang membership, permissions, mission state, and progression remain JSON fields within their entity row in this version. This is entity-separated storage with normalized player/gang inventories, not a fully relational redesign of every gameplay field.

Identifiers are case-sensitive. Treat generated license, gang, zone, drop, item, and wipe keys as canonical machine identifiers; reject trailing spaces rather than relying on padded string comparisons. User-facing names remain payload values. Require valid UTF-8 identifiers of at most the declared column length. The connector must use `utf8mb4`.

Item quantities must be nonnegative safe integers validated by the adapter before SQL. An absent item and a zero-quantity item are gameplay-equivalent; choose a consistent storage convention. Owner foreign keys prevent orphan inventory rows and cascade item deletion when the seasonal owner is removed. The schema does not expose a client SQL API or permit clients to assign balances.

## Transaction protocol

The Lua adapter currently serializes shared-state transitions. All storage writers must also follow this database protocol, including wipes, restore/import tools, and future admin tooling:

1. Begin an InnoDB transaction and read `nst_meta WHERE id=1 FOR UPDATE`.
2. Compare the expected revision and season against the locked row. A stale revision fails without applying speculative changes.
3. Read/reconstruct the current state in the same transaction. Write only changed entity payloads and item rows. Create parent rows before inventory rows; owner deletion cascades inventory removal.
4. Increment the singleton revision and append `nst_audit` in the same transaction.
5. Commit, then publish effects. Roll back on failure. If the network outcome is unknown, reload state before accepting another speculative mutation; never blindly replay a payout.

Read envelopes must use a consistent transaction or the same singleton lock so that entity rows and revision cannot come from different commits. A global revision lock is retained for correctness with the current full-state Lua API. Splitting tables reduces write volume but does **not** make current gameplay mutations parallel or establish a measured player capacity. Direct external writes that bypass this protocol are unsupported.

## Persistent and operational data

| Table | Columns / purpose |
|---|---|
| `nst_accounts` | `identifier`, `admin`, JSON `settings`; separate from seasonal player rows |
| `nst_bans` | `identifier`, `reason`, nullable UNIX `expires_at` |
| `nst_settings` | `setting_key`, JSON `value` |
| `nst_backups` | `backup_id`, UNIX `created_at`, `revision`, JSON `payload`, lowercase hexadecimal `sha256` |
| `nst_wipes` | Unique `wipe_key`, `previous_season`, UNIX `completed_at`, referenced `backup_id` |
| `nst_season_history` | Unique `season`, UNIX `ended_at`, JSON `leaderboard` |
| `nst_audit` | Auto-increment `id`, UNIX `at`, bounded `action`/`actor`, `revision` |
| `nst_schema_migrations` | `version`, database-generated `applied_at` timestamp |

Runtime timestamps other than the migration marker are UTC UNIX seconds. Europe/Stockholm scheduling and daylight-saving decisions belong to the scheduler, not the MariaDB session time zone. Account/admin/ban tables are persistent storage: their existence alone does not implement txAdmin permissions or connection bans.

## Wipe and recovery requirements

A wipe locks the singleton and checks `nst_wipes` before changing state. A completed key is a no-op. The pre-wipe backup, season ranking, seasonal reset, next deadline, revision, audit record, and wipe marker must commit atomically. Only the seasonal entity/inventory tables and seasonal metadata reset. Preserve accounts, bans, settings, backups, wipe history, rankings, and audit records. Do not use `TRUNCATE` inside this transaction: use transactional `DELETE` statements and preserve the foreign-key order.

A logical backup payload must include the pre-wipe season state and its revision/deadline; define any additional persistent content in the runtime export format. SHA256 covers the exact stored UTF-8 payload bytes. Backups inside the same MariaDB database protect against application-level resets, not database loss or deletion. Operators must also keep tested backups outside that database. Restore into a fresh dedicated database for inspection; do not overwrite live player data automatically. Replaying a restored expired deadline can trigger a new scheduled wipe unless an explicit restore option reschedules it.

DDL has implicit commit behavior. Apply migrations before enabling gameplay, not inside a gameplay/wipe transaction. `CREATE TABLE IF NOT EXISTS` does not upgrade incompatible existing tables; use a later explicit migration when changing schema, and refuse unsupported schema versions. A runtime account normally needs SELECT/INSERT/UPDATE/DELETE on these tables; use a separate installer account for CREATE and future ALTER permissions.

## Verification status

The Node backend passed nine integration cases on isolated MariaDB 11.4.5 on 2026-11-16: entity/item round trips, competing claims, changed-row writes, rollback, persistent data, wipe idempotence, failures around commit, overdue wipe and backup/hash/restore checks. The fixture was stopped afterward. No remote migration was attempted. Actual FiveM, physical power loss, deployment network/TLS and load behavior remain unverified.
