# In-server automatic updates

The `nst_updater` FiveM resource checks an approved GitHub release feed on each full server startup. No Python, shell script, Git installation, external service or scheduled task is required on the server.

## First installation on an existing server

Stop the server application in txAdmin. Back up your resource folders and configuration. Download the v0.4.0 prebuilt release ZIP. Replace the `no_safe_turf` program files with its `resource` folder, including `update-state.json`, while preserving your existing `shared/config.lua`. Copy its `updater` folder to `resources/[local]/nst_updater`. Do not replace your server.cfg, database configuration, backups or database. This one manual installation establishes the checksums required for future updates.

After your existing `ensure oxmysql`, use this order in server.cfg:

```cfg
set nst_auto_update 1
add_filesystem_permission nst_updater write no_safe_turf
ensure nst_updater
ensure no_safe_turf
```

Restart the server application. Check the `[NST Updater]` messages and run `nst_update_status`, `nst_db_status` and `nst_status` in the server console. Fresh recipe installations include this setup.

## Behavior and scope

The updater holds game resource startup and declines connections during its startup check. It fetches `updates/stable.json` from this repository and installs only a newer approved bundle from this repository's releases. HTTPS, bundle SHA-256 and individual file hashes protect transfer integrity; the repository and its maintainers remain trusted to publish executable code. This is not an independently signed update channel.

Only allowlisted Lua, JavaScript, HTML and CSS files plus fxmanifest.lua are managed. `shared/config.lua`, database credentials, SQL data, backups, dependencies and the updater itself are excluded. Updates must retain the same managed file set and compatibility level. Changed code files, added/removed files, dependency upgrades and schema/configuration changes require manual installation. Release maintainers must not publish incompatible changes to this feed.

Before writing, the updater saves and verifies a recovery journal and retains a backup under `nst_updater/backups`. Write failures trigger rollback. A pending journal is recovered before subsequent startup checks, even when auto updates are disabled. Unreadable or unrecoverable journals block game startup. Preserve the pending journal and backups when investigating; do not delete them just to bypass the gate. Disk failure or power loss can still require manual restoration from backup.

Network errors leave the existing installation available, provided no unresolved update journal remains. The updater does not hot-update a running game resource. Use a full server application restart, not `restart nst_updater`. Backup files accumulate and may be archived manually while the server is stopped and no journal is pending.

Set `nst_auto_update 0` to skip downloads. Keep the updater enabled until any pending recovery finishes.

## Release workflow and validation

`node tools/build-update.js` generates the checksum baseline and `dist/nst-update.json`. `tools/package.ps1` runs this automatically before packaging. Upload the bundle to the matching versioned GitHub release before copying `dist/stable.json` to `updates/stable.json` and publishing the feed. Build from the exact bytes included in the release ZIP; line-ending conversion after packaging invalidates checksums.

Unit tests cover path restrictions, hashes, custom configuration preservation, local edits, incompatible file sets, rollback and interrupted recovery. Actual Enhanced filesystem permission behavior and startup event ordering must also be verified on a test server before relying on unattended updates.
