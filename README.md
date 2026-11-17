# NO SAFE TURF · 0.3.1

Standalone English crime/survival for FiveM Enhanced: two robberies, gangs, shared cash/storage, player police, arrests, death loot, hideouts, raids, territories and weekly seasons. Open F6 or /nst.

## Installation

Use [the txAdmin recipe guide](docs/TXADMIN_RECIPE.md) for a new test profile, or [external MariaDB/manual installation](docs/MARIADB.md) for a pre-created database or existing server. Runtime requires external MariaDB 10.11+, oxmysql 2.14.3, embedded Node 22, OneSync and the matching Enhanced client/server. No Python, paid resources or frontend build is required.

Fresh installs use the [main-branch recipe](https://raw.githubusercontent.com/FiveEYZ/NO-SAFE-TURF/main/recipe.yaml) and the versioned v0.3.1 release asset. This patch fixes raw slashes in txAdmin database passwords and removes the Legacy-only recipe build threshold. It adjusts the pinned oxmysql manifest's server constraint for Enhanced build 177 while retaining Node 22. A complete Enhanced deployment and player connection still need verification.

## Current evidence

npm test runs JavaScript/NUI/config/transport checks and five Lua 5.4 suites via Wasmoon without Python. Fifteen disposable MariaDB integration cases pass, including failed backup, file restore, connection loss/reconnection and the oxmysql transport contract. These do not execute oxmysql inside Cfx.

Actual Enhanced startup, txAdmin Server Deployer, external-host TLS/grants, two-client gameplay and 16–32-player capacity remain unverified. Read [requirements status](docs/REQUIREMENTS.md), [test protocol](docs/TESTING.md) and [limitations](docs/LIMITATIONS.md).

## Development

Install Node 22+ and PowerShell 7. Run npm ci --ignore-scripts in the root, then npm ci --omit=dev --ignore-scripts --prefix resource for the offline database tools. Run npm test. The UI is plain HTML/CSS/JavaScript: source files in resource/web are the final runtime files; no bundler is needed.

npm run test:database uses an optional disposable Windows MariaDB fixture under .testtools, never deployment credentials. tools/package.ps1 builds secret-screened archives. Legacy Python reference files remain in the working repository but are not part of the maintained build/test flow or release.

## Administration

Console: nst_db_status and nst_status. Console or ACE nst.admin: nst_wipe dryrun UNIQUE_KEY and nst_wipe execute UNIQUE_KEY. Default wipe: Sunday 04:00 Europe/Stockholm. Destructive wipe requires a synced, read-back-verified external-to-database archive. Missing/unwritable backup storage blocks the wipe and overdue economy.

[Gameplay](docs/GAMEPLAY.md) · [Police](docs/POLICE.md) · [Operations](docs/OPERATIONS.md) · [Upgrades](docs/UPGRADING.md) · [Compatibility/licenses](docs/COMPATIBILITY.md) · [Agent instructions](AGENTS.md)
