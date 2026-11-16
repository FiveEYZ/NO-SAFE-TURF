# txAdmin + MariaDB installation (0.2)

For automated recipe installation without a separate private JSON or offline initialization command, see [TXADMIN_RECIPE.md](TXADMIN_RECIPE.md). The manual instructions below remain supported.

## Architecture

Lua gameplay → local server export → FiveM JavaScript/Node 22 → MariaDB.

Python, oxmysql, separate storage services and HTTP tokens are not required. The manifest selects Node 22. See [Cfx JavaScript runtime documentation](https://docs.fivem.net/docs/scripting-manual/runtimes/javascript/) for embedded Node and main-thread callbacks. Actual Cfx interoperation still needs the two-client test.

## Prepare and install

1. Use a dedicated database on MariaDB 10.11 or newer, with a maintained patched release. Permit connections from the FiveM host. Runtime permissions: SELECT/INSERT/UPDATE/DELETE. Initialization additionally needs CREATE. Do not reuse unrelated application tables.
2. Extract the release. Copy the contents of resource/ into resources/[local]/no_safe_turf/ under your txAdmin server data directory, including node_modules. fxmanifest.lua must be directly in no_safe_turf. For a source checkout, first run: npm ci --omit=dev --ignore-scripts --prefix resource.
3. Copy deploy/mariadb.example.json to a private JSON file and set host, port, user, password and database. In this workspace, supplied credentials are already in deploy/mariadb.private.json. Transfer that file separately to no_safe_turf/server/mariadb.private.json. The release excludes credentials. Restrict access to the server account. Never add this file to manifest files/shared_scripts or expose it through a web server. Optional sslCa names a CA certificate relative to the JSON file; certificate and host verification remain enabled.
4. From the extracted release directory on an administrator computer with Node 22+, run the commands below with the intended private configuration. Check is read-only; init creates tables and the initial season. Initialization has not been run against your database.

    node tools/database.js check --config deploy/mariadb.private.json
    node tools/database.js init --config deploy/mariadb.private.json

5. Merge deploy/txadmin-resource.cfg into the existing txAdmin server.cfg, preserving endpoints, license and administrator settings. Do not run competing economy/inventory/spawn frameworks.
6. Start through txAdmin. Run nst_db_status in the server console, then nst_status. Complete TESTING.md with two private clients before using real player data.

The SQL file alone creates tables; the init tool also creates the singleton season/deadline row. Startup verifies schema version and metadata. It does not automatically create the schema.

A saved deadline survives restart. Schedule convars affect later calculations; use matching --weekday, --hour and --minute initialization options when changing defaults. Monday=0; default Sunday=6 at 04:00 Europe/Stockholm.

## Backup export and restore

Every completed wipe creates a transactional pre-wipe backup. Find its ID in nst_backups (backup_id, created_at, revision) or the wipe result. Export to a new file:

    node tools/database.js export --config deploy/mariadb.private.json --id BACKUP_ID --file season.backup.json

With the resource stopped, restore into a new dedicated empty destination database:

    node tools/database.js init --config destination.private.json
    node tools/database.js restore --config destination.private.json --file season.backup.json --reschedule

Restore refuses occupied databases and checks payload hashes and historical references. --reschedule assigns a future deadline; omitting it retains the archived deadline and can trigger an overdue wipe on startup. Inspect the destination before switching the resource configuration. Keep off-host database backups too.

There is no automatic SQLite importer. Retained Python files are legacy/reference; do not run that service against the active v0.2 database.

## Isolated test fixture

tests/run_mariadb_node.js expects the portable Windows MariaDB distribution at .testtools/mariadb-11.4.5-winx64. This historical version is a disposable test fixture, not a production recommendation. The harness creates a random loopback port, password and data directory, runs nine integration cases and stops its own process. It never reads deployment credentials or installs a service.

