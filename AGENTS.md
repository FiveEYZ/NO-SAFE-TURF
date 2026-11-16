# NO SAFE TURF contributor instructions

## Constraints

Continue existing work. English code identifiers, player/admin strings and delivered documentation; Swedish user reports. No production changes, publishing, real-data restore, destructive migrations or real wipes without explicit user approval. Never print, commit or package private credentials. Do not run deployment configuration against real databases during tests.

## Architecture

Standalone FiveM Enhanced Lua gameplay and prebuilt HTML/CSS/JavaScript NUI. Server-local JavaScript storage uses pinned oxmysql 2.14.3 with external MariaDB and revision-checked transactions. mysql2 remains for offline tools/tests. nst_database_config validates private configuration before oxmysql. Wipes require verified filesystem backups. No Python build/test/installation/runtime/backup dependency in the maintained delivery.

Gameplay handlers NST.handlers[action](state,context,args) are synchronous pure state transitions; the adapter persists changes before client effects. Storage returns revision/state/nextWipe envelopes. Never retry an uncertain write as a new revision without reconciliation. Weekly schedule defaults to Europe/Stockholm.

## Current ownership (2026-11-16 requirements update)

- Lead: server/core.lua, server/main.lua, client/main.lua, shared locales/manifest wiring, recipe.yaml, deploy/, tools/, tests runners, package metadata, integration and documentation.
- Gameplay (Sol High): server/gameplay.lua, shared/config.lua, tests/gameplay_spec.lua, tests/integration_spec.lua, docs/GAMEPLAY.md; gameplay-specific locale file if needed.
- Police/combat (Sol High): server/police.lua, tests/police_spec.lua, docs/POLICE.md; police-specific locale file if needed. Propose adapter/client changes to lead, do not edit those files.
- Infrastructure (Sol High): server/storage.js, server/storage/, tests/mariadb_node_spec.js, tests/config_spec.js, tests/bridge_spec.js, database/, docs/MARIADB.md, docs/MARIADB_SCHEMA.md, docs/OPERATIONS.md. Propose recipe/UI changes to lead.
- Independent review (Astra High): read-only critical review, scheduled after a slot is available. Luna Medium may handle bounded documentation later.

No concurrent edits to another owner's files. Announce interface changes before implementation. Request cross-review of economy, permissions, concurrency, wipe and recovery changes. Four active agents maximum including lead.

## Checks

- npm test: JavaScript checks plus five Lua 5.4 suites via pinned Wasmoon; no Python.
- node tests/run_mariadb_node.js: disposable loopback MariaDB fixture, never production; requires existing portable binaries under .testtools.
- tools/package.ps1 (PowerShell 7): secret-screened release packaging.
- node tests/recipe_spec.js --files: local recipe file replay using downloaded pinned archives; not actual txAdmin execution.

The three Sol agents reached usage limits after partial implementation; lead completed integration. Astra performed independent critical review and Luna wrote bounded requirements/upgrade documentation. Main runtime, transport, language, recovery and package changes are now lead-owned. No further parallel edits without a new ownership assignment.

Do not claim Cfx startup, Enhanced native behavior, external DB connectivity, txAdmin deployment, URL availability or multiplayer playtests without actual evidence. Record versions, licenses, test outcomes and blockers in docs. Keep this file updated when ownership or test commands change.
