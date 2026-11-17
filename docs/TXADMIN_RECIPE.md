# txAdmin installation recipe · 0.3.2

This custom engine-3 recipe uses documented actions and the official Enhanced base-resource structure. It does not need inclusion in the official popular-recipes list. All NUI and upstream runtime files are prebuilt.

## Release and installation URL

Use https://raw.githubusercontent.com/FiveEYZ/NO-SAFE-TURF/main/recipe.yaml with the matching v0.3.2 release asset. See RELEASE_0.3.2.md for Enhanced compatibility adjustments. The upstream oxmysql manifest is adapted from /server:12913 to /server:177; Node 22 remains required. Full Enhanced deployment is still unverified.

## Fresh installation

1. Use an isolated txAdmin profile, a proper Enhanced server artifact supporting embedded Node 22, licensed clients and your Cfx server key.
2. Select Remote URL Template and use the published raw recipe. Choose a fresh server data directory and dedicated empty MariaDB 10.11+ database. Target 16–32 clients; do not assume the deployer's default slot count is load-tested.
3. Enter database host, port, database, user and password in txAdmin. The recipe forces dbDelete=false, checks database compatibility and rejects existing nst_* tables before importing schema. Do not use the fresh installer to upgrade.
4. Review generated server.cfg and start. Resource order: mapmanager/spawnmanager, nst_database_config, oxmysql, no_safe_turf. The private connection URL is converted by the preloader; the first season is initialized only on an empty schema.
5. Run nst_db_status and nst_status. Confirm server-backups is private and writable before scheduling seasons. Open F6 in game and complete TESTING.md before any production decision.

Server listing metadata belongs in Cfx Portal following the official Enhanced template. The generated cfg preserves documented maxClients/serverEndpoints/svLicense/addPrincipalsMaster/dbConnectionString placeholders. ACE administrators can use nst.admin commands.

## Pinned inputs and prerequisites

- oxmysql v2.14.3 release ZIP: SHA256 F6DB8F612A36A8A75FCCDE300E8C4135696B5BBCA5770CD7F26458949E1F7872.
- Cfx server-data commit 32d98e7524b952faf8b220d719615b0346b0a6cc. Downloaded archive SHA256 7A394DC03E0B0999DD13269EA471436B00E80DCDEE974D7CD727FFACA95E733B.
- Mod release v0.3.2; publish the matching reviewed ZIP, not GitHub's source-only ZIP.

Upstream archive downloads, paths and manifests were inspected locally. Standard documented recipe actions do not provide a hash-verification field, so no invented action is used; version references are locked and build-time checksums recorded. Preserve release assets rather than replacing them under the same tag.

The official connect_database implementation always attempts CREATE DATABASE IF NOT EXISTS and has no documented CA input. If the provider forbids that command or requires custom-CA TLS at installation, use the manual/pre-created database path in MARIADB.md and txAdmin's existing-server-data flow. The recipe cannot change this engine limitation.

## Verification boundary

The local recipe smoke test replays file operations against downloaded pinned archives and the built local release. SQL is tested separately on disposable MariaDB. This is not execution of txAdmin Server Deployer, the remote release or Cfx natives. Run these checks on the actual Enhanced server with licensed test clients.

Sources: [official recipes](https://github.com/citizenfx/txAdmin-recipes), [recipe documentation](https://github.com/citizenfx/txAdmin/blob/master/docs/recipe.md), [database action implementation](https://github.com/citizenfx/txAdmin/blob/master/core/deployer/recipeEngine.js).
