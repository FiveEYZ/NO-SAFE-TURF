# NO SAFE TURF · 0.2.1

Standalone FiveM resource: robberies, gangs, shared storage, player police, arrests, death loot, hideouts, raids, territories and weekly seasons. Open the English interface with F6 or /nst.

**Python is not required to run the mod.** Lua gameplay calls server-side JavaScript inside FiveM, which connects directly to MariaDB. txAdmin starts and stops the resource. There is no separate storage service or HTTP port.

## Installation

For automated setup, use the [txAdmin recipe guide](docs/TXADMIN_RECIPE.md) and root recipe.yaml. Publish the matching release asset first.

Follow [the txAdmin and MariaDB guide](docs/MARIADB.md). Copy the packaged resource including its dependencies, transfer the private database configuration separately, initialize the dedicated schema explicitly and merge the txAdmin configuration fragment.

Requirements: an appropriate FiveM Enhanced artifact with Node 22 support, OneSync, the base map/session/spawn resources, licensed GTA V Enhanced clients and MariaDB 10.11+. Optional offline database tools require Node 22+ on the administrator computer. The packaged game server uses FiveM's embedded Node runtime.

## Verification

Local JavaScript, Lua, UI and isolated MariaDB checks pass. Actual FiveM startup, Lua/JavaScript interoperation in Cfx and Enhanced multiplayer still require the [two-client protocol](docs/TESTING.md). 16–32 players is a target, not measured capacity. Combat currently uses fists, bats and police batons.

Run node tests/run_node.js for JavaScript checks. Run node tests/run_mariadb_node.js for isolated Windows database tests with the portable fixture installed. The retained Python service/tests are development/reference only and excluded from the deployment package.

## Playing and administration

Start with a store robbery, sell stolen goods to the fence and save for a gang and hideout. The depot requires a police officer and a lockpick. GPS buttons and blips show locations.

Console: nst_db_status. Console or ACE nst.admin: nst_status, nst_wipe dryrun test-01, nst_wipe execute test-01. Execute resets seasonal data; use only on the intended database. Default schedule: Sunday 04:00 Europe/Stockholm.

[Gameplay](docs/GAMEPLAY.md) · [Police](docs/POLICE.md) · [Operations](docs/OPERATIONS.md) · [Compatibility](docs/COMPATIBILITY.md) · [Limitations](docs/LIMITATIONS.md) · [Architecture](docs/PLAN.md) · [License](LICENSE)

