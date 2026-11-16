# NO SAFE TURF — first version

2026-11-15. The workspace was empty; no AGENTS.md files were found in the directory or its parent directories.

Standalone Lua was selected to avoid framework migration and paid assets. NUI uses plain HTML/CSS/JS. Server-side JavaScript inside FiveM uses MariaDB with transactions, revision checks and pre-wipe backups. The server serializes gameplay commands; state is published only after storage. The snapshot model targets 16–32 players and has not been verified for larger loads.

2026-11-16 deployment update: the target is self-hosted txAdmin plus MariaDB. The local server export now uses MariaDB with InnoDB, entity-separated rows, normalized player/gang item rows, and updates limited to changed rows. Python/SQLite remain optional development/reference code, excluded from the deployment package. The global revision lock remains because the Lua API still submits shared-state transitions. MariaDB schema initialization and restore are explicit offline operations. See [deployment guide](MARIADB.md).

## File ownership and interfaces

- Lead agent: core/main, client, NUI, manifest, installation, and integration tests.
- Gameplay agent: gameplay.lua, config.lua, gameplay_spec.lua, GAMEPLAY.md.
- Police agent: police.lua, police_spec.lua, POLICE.md.
- Infrastructure agent: service/, test_service.py, OPERATIONS.md.

Gameplay and police modules register pure `NST.handlers[action](state,context,args)` functions. Context contains server-derived identity, time, position, and connected players. An error discards the entire state copy. Handlers must not yield. The JavaScript storage adapter checks the revision and writes state and audit records atomically. Identity uses the license identifier, never a reusable connection number. Data sent to NUI is filtered per player.

## Delivery order

1. Resource, core, database, and API.
2. Robbery → stolen goods → fence/hideout storage.
3. Gangs, police, arrests, and death.
4. Hideouts, raids, and territories.
5. Wipes, history, backups, and administration.
6. Cross-review, actual local tests, and a manual two-client protocol.

All coordinates and balance values are initial test values. No public server is opened. No custom streamed maps or models are required. GTA/FXServer testing, checking positions in the game, and load testing are separate acceptance gates. English is the default project and interface language; the wipe schedule retains the Europe/Stockholm time zone.

