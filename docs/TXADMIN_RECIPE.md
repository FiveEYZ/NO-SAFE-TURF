# txAdmin recipe

This custom recipe follows the official Enhanced Basic Server structure and uses the documented engine 3 actions. It is not an officially endorsed/popular recipe.

## Publish once

1. Upload the source, including root recipe.yaml, to FiveEYZ/NO-SAFE-TURF. Never upload deploy/mariadb.private.json, generated server.cfg, .testdata or credentials.
2. Run tools/package.ps1 with PowerShell 7 from the source workspace. It creates a regular archive and dist/no-safe-turf-txadmin.zip containing the installed mysql2 dependencies. No npm installation is needed on the game server.
3. Create a GitHub Release tagged v0.2.1 and attach no-safe-turf-txadmin.zip with that exact filename. The release asset must be reachable by txAdmin without authentication. A source-only ZIP is insufficient because node_modules is ignored by Git.
4. If your default branch is main, the recipe address is:

    https://raw.githubusercontent.com/FiveEYZ/NO-SAFE-TURF/main/recipe.yaml

Use the actual branch in that address if different. The repository branch, permissions and release availability have not been verified from this workspace. Publishing has not been performed.

## Install

1. Start a new txAdmin profile using an Enhanced server artifact with embedded Node 22 support. Choose Remote URL Template and enter the raw recipe URL above. Use a fresh server data directory.
2. Enter your Cfx license and database details in txAdmin. For your LAN deployment the host is 192.168.1.5, port 3306, and supplied user/database is NST_Bredbyn. Enter the password privately in the form. Do not select an option that deletes an existing database. A fresh dedicated database is preferred; the recipe also accepts txAdmin-generated database names.
3. Run the recipe. It connects to MariaDB, downloads the release, imports the schema and installs the base resources and mod. The database must be MariaDB 10.11+; the account needs CREATE for deployment and SELECT/INSERT/UPDATE/DELETE at runtime.
4. Review and save server.cfg in txAdmin, then start. The first startup initializes the season only if all application tables are empty and metadata is absent. Existing metadata is preserved. Run nst_db_status and nst_status in the console.
5. Join with an Enhanced client and press F6. Follow TESTING.md before production use. Configure server listing metadata in Cfx Portal as required by the official Enhanced template.

No private JSON file is required for recipe installs: the mod reads the server-only nst_db_connection convar populated from txAdmin's dbConnectionString. Manual private JSON installs remain supported when that convar is empty. Never publish the generated server.cfg or use replicated convars for credentials.

The recipe does not install basic-gamemode because NO SAFE TURF controls spawning and gameplay. Base mapmanager/spawnmanager follow the official recipe's master reference; pin a reviewed Cfx commit before a reproducible public release. Existing off-host backup and restore procedures remain necessary.

## Validation and limits

Local checks cover connection-string parsing, first-start bootstrap, preservation of existing metadata, refusal to bootstrap occupied tables, and existing database regression cases. Actual txAdmin deployment/downloads and in-game startup remain untested. Recipe execution creates database tables; no deployment database was modified while preparing these files.

Sources: [official recipe guidelines](https://github.com/citizenfx/txAdmin-recipes), [recipe actions](https://github.com/citizenfx/txAdmin/blob/master/docs/recipe.md), [Enhanced template](https://github.com/citizenfx/txAdmin-recipes/tree/main/default-fivem-enhanced).
