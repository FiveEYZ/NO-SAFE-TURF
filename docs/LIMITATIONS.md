# Known limitations and priorities

## Acceptance before playtesting

No GTA client, Cfx server key, or Enhanced server installation has been configured or used for this project. Resource startup, native behavior, NUI rendering, map coordinates, cell interior, spawn model, police vehicles, and two simultaneous clients are therefore **not verified in the game**. Follow TESTING.md and record the actual artifact version. The code is a locally tested prototype, not an approved production server.

## First-version scope

- Combat uses fists, baseball bats, and police batons. Firearms/ammunition accounting are not included. Arrest requires the suspect to surrender; there is no forced arrest of a moving or dead character.
- The two robberies use stationary store/depot objectives with different tools, staffing requirements, durations, and rewards. There are no AI police, escorts, minigames, or transport missions with custom mission vehicles.
- Activities are located in southern/central Los Santos. No physical map boundary prevents exploration of the rest of the map.
- Hideouts are fixed interaction points, without custom interiors or construction systems. Upgrades reduce raid losses to 25/20/15 percent. Offline protection lasts 15 minutes after the last defender's presence, after which a raid can begin. Raids may start at any time of day; their warning and activity windows govern the attack itself.
- A gang leader cannot leave a gang that has other members or a purchased hideout. Leadership transfer and dissolution with asset distribution require a later version.
- The Stockholm schedule uses the embedded Node runtime Intl time-zone data. Future changes to time-zone rules require an update and retesting. Indefinite operation without maintenance is not promised.
- Gameplay transitions still serialize the shared game state. MariaDB stores separate entities/inventory rows and writes only changes; it retains a global revision lock and reconstructs snapshots on reads. Data volume, tick latency, and operation with 16–32 players need measurement; revision conflicts reject actions and require a retry. Storage outages stop the economy. A medkit can be consumed without visible healing if the server crashes between commit and the client effect; the item is not automatically refunded.
- MariaDB has been tested on an isolated local 11.4.5 instance, not against the deployment database, its grants, network or TLS configuration. Storage runs inside FiveM; actual Cfx Lua/JavaScript interoperability still needs verification. Existing SQLite player data is not automatically migrated. Logical backups share the database until explicitly exported; keep external server backups too.
- Starting cash is granted once per license per wipe. Purchased alternate accounts and cooperating rival gangs cannot be detected completely. Simply logging in provides no automatic reward.
- The server uses replicated position/health, but teleport cheats and manipulated client physics require movement analysis and separate anticheat. Spawn protection against damage events is checked by the server; vehicle collisions/explosions need specific in-game verification.
- Account tables and history survive wipes. ACE and Cfx/txAdmin handle active administrator/ban management; the bans SQL table is not a separately implemented connection block.
- English frontend text is collected in locale.js; English gameplay validation messages reside in their respective Lua modules. A complete backend localization layer remains future work.
- No voice integration, statistics export, performance dashboard, or web administration. Standard game assets are referenced; no third-party models are distributed.

## Next work, in order

1. Run the Enhanced two-client protocol, fix natives/coordinates, and record approved versions.
2. Profile 16 and 32 players, database size, 24-hour operation, and slow/interrupted database requests.
3. Extend combat with server-accounted ammunition, vehicle damage, forced arrest, and movement validation.
4. Add leadership transfer, better storage management, a complete localization layer, and interface testing in actual NUI.
5. Balance-test multiple seasons, add robbery types, and improve protection against alternate accounts and coordinated farming.

