# External MariaDB and manual installation

## Connection and dependencies

The runtime path is Lua → local JavaScript storage → pinned oxmysql 2.14.3 → external MariaDB 10.11+. Existing transaction/revision logic is preserved. mysql2 3.14.1 remains bundled only for offline tools and disposable tests. No local database is an installation requirement. Never run two gameplay instances against the same database.

Install the official [oxmysql 2.14.3 release](https://github.com/overextended/oxmysql/releases/tag/v2.14.3). Its manifest requires server build 12913 or newer and Node 22; choose a current Enhanced artifact, not a Legacy artifact merely meeting that number. [Official oxmysql documentation](https://overextended.dev/docs/oxmysql) recommends MariaDB. The adapter uses the pinned startTransaction API and waits for commit acknowledgement. Cfx cross-resource Promise behavior is still unverified.

## Manual / existing-server installation

1. Stop the test resource. Preserve your existing server.cfg, keys, private connection files and backups. Follow UPGRADING.md before changing a server with player data.
2. Copy resource/ to resources/[local]/no_safe_turf/ and database_config/ to resources/[local]/nst_database_config/. Keep manifest files directly inside those resource folders. Extract the pinned oxmysql resource to resources/[standalone]/oxmysql/.
3. Copy deploy/mariadb.example.json to no_safe_turf/server/mariadb.private.json. Configure host, port, database, user and password privately. No file containing these values belongs in Git or the manifest file list. Use a dedicated database.
4. From the extracted package on an administrator computer with Node 22+, run:

    node tools/database.js check --config PATH_TO_PRIVATE_JSON
    node tools/database.js init --config PATH_TO_PRIVATE_JSON

Check is read-only. Init applies nst_* tables and initializes the first season only if metadata is absent and all application tables are empty. It never creates a database. This supports a pre-created database when the provider prohibits CREATE DATABASE. DDL is not fully transactional; after an installation error inspect the partial schema, do not drop/reset existing data.
5. Merge deploy/txadmin-resource.cfg into your existing profile. Set nst_backup_directory to server-backups. Start order: nst_database_config, oxmysql, no_safe_turf (mapmanager/spawnmanager also required). Restart that sequence after changing connection settings.
6. Run nst_db_status and nst_status, then the private two-client protocol. Do not start a competing economy/spawn/inventory framework.

## txAdmin database permissions and constraints

The official recipe engine inspected on 2026-11-16 always issues CREATE DATABASE IF NOT EXISTS, even for a named existing database. The fresh recipe forces dbDelete=false and refuses an existing nst_* schema. [Engine source](https://github.com/citizenfx/txAdmin/blob/master/core/deployer/recipeEngine.js) is authoritative for this behavior.

A provider that rejects CREATE DATABASE must use the manual path above and txAdmin's existing-server-data flow. The normal recipe cannot bypass the engine's database command. The inspected deployer connector also has no documented TLS-CA recipe input. If the provider requires custom-CA TLS during installation, use the offline tool/private JSON path rather than weakening verification.

Installer: CREATE for this database's tables plus SELECT/INSERT/UPDATE/DELETE; the regular deployer may additionally need permission for its CREATE DATABASE command. Runtime: SELECT/INSERT/UPDATE/DELETE only. No DROP/ALTER permission is needed for v1 runtime operations. Tables explicitly use InnoDB and utf8mb4_bin even if txAdmin's database default differs. Existing incompatible schemas are not upgraded by IF NOT EXISTS.

## Private configuration and TLS

Recipe installs pass the server-only nst_db_connection URL from txAdmin. Manual installs use private JSON when that convar is empty. The nst_database_config preloader validates and converts the URL before oxmysql starts. Never use setr or sets for secrets.

Pinned oxmysql's configuration parser cannot safely represent semicolons, equals signs, control characters or the substring mysql:// inside individual credentials/host/database fields. Such inputs are rejected without logging them. Normal URL-encoded slash, colon, at-sign and percent characters are decoded before conversion. Unsupported credentials require an operator-supplied compatible database account; this project never changes passwords automatically.

For private JSON, sslCa is the path to a trusted CA PEM file relative to that JSON. For recipe URL connections, set nst_db_ssl_ca to a CA PEM file relative to no_safe_turf. Both configure rejectUnauthorized=true and verifyIdentity=true. Without a CA setting TLS is not enabled by this adapter; use it only on your intended trusted network. There is no insecure-TLS switch. Host identity must match the certificate.

Database diagnostics are sanitized; keep oxmysql debug/UI disabled as supplied. Restrict generated server.cfg/private JSON/backup directory access to the server account. Do not expose the resource directory through an HTTP server.

## Backup and restore

See OPERATIONS.md. The filesystem archive can be restored with the Node tool into a freshly initialized destination. No Python or MariaDB process on the game host is required. Off-host copies and whole-database provider backups remain necessary for machine/disk loss.

## Isolated development fixture

tests/run_mariadb_node.js uses the optional portable MariaDB 11.4.5 Windows distribution in .testtools/mariadb-11.4.5-winx64. This historical test fixture is not a production version recommendation. Each run uses a random loopback port, fresh credentials and a new data directory; it stops its own process and never reads deployment credentials.
