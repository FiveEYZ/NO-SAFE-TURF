# Verification protocol · v0.7.3

Status updated 2026-11-18. Record the tested commit, release and local configuration alongside every result. Passing local tests does not establish real-client or multiplayer acceptance.

## Automated checks and evidence

| Check | Latest recorded result | Scope and limits |
|---|---|---|
| `npm test` | Passed for v0.7.3, 2026-11-18 | JavaScript checks, updater startup/recovery and file safety, 209 schedule/DST cases, database configuration and mocked storage contracts, NUI requests/live snapshots/pointer placement, recipe structure; Lua compilation and adapter, client, gameplay, integration, police, inventory, grid and firearms suites. Does not launch FXServer or a GTA client. |
| `npm run test:database` | Historical pass: 15 disposable MariaDB 11.4.5 cases, 2026-11-16; not rerun for v0.7.3 | Transactions, concurrent claims, disconnect/reconnect, backups, restore, corruption and wipe idempotence. The oxmysql proxy exercises its export contract over real SQL, not the Cfx export boundary. |
| `node tests/recipe_spec.js --files` | Historical local replay, 2026-11-16; not rerun for v0.7.3 | Replays local recipe file operations with pinned upstream archives. Does not run txAdmin or apply SQL to a remote host. |
| `pwsh -NoProfile -File tools/package.ps1` | Passed for v0.7.3, 2026-11-18 | Credential screening, excluded private/test files, archive entries and updater bundle generation. |
| Chrome layout preview | Checked at 1600×1000 and 1280×720 for v0.7.3 | Larger right-docked panels, transparent outer window and responsive sizing. Browser fixtures do not prove in-game mouse/focus behavior. |
| Published release verification | v0.7.3 ZIP and update JSON downloaded and byte-compared, 2026-11-18 | Both matched the built artifacts before publishing the stable update feed. No new runtime files or SQL migration in this release. |

Root `npm ci --ignore-scripts` prepares the test dependencies. Node 22 or newer is required; Lua 5.4 tests use pinned Wasmoon. Offline database tooling uses mysql2; server storage uses pinned oxmysql 2.14.3. No Python is required. Run database and destructive recovery tests only against disposable local fixtures, never production. See [MariaDB](MARIADB.md) and [operations](OPERATIONS.md).

The optional MariaDB 11.4.5 Windows fixture recorded on 2026-11-16 had SHA256 `b7c11d38657f16b837e68199d73670510aadb78f42dfa5d5fdea31a7aab342e3`. Fixture binaries are not deployment dependencies.

## Operator-reported hosting observations

Earlier operator logs confirmed Enhanced FXServer resource startup, an external MariaDB connection, successful `nst_db_status`, persisted season/revision reporting, and the updater holding gameplay startup until its check completed. Screenshots confirmed the English HUD and inventory rendering; the operator subsequently reported a visible character. These are observations from earlier builds, not a complete v0.7.3 acceptance run. Spawn collision, pointer interactions, combat and multiplayer behavior still need the checks below.

## Inventory and updater acceptance — NOT RUN for v0.7.3

Use an isolated server and disposable database. Record client/server versions, release, resolution, UI scale, results and relevant logs. All player-facing text should remain English.

| Test | Expected result | Actual |
|---|---|---|
| Connect and spawn, then reconnect | Loading screen ends; character and terrain appear; character does not fall through the world | Not run |
| Open TAB / `/nst_inventory`, then F6 / `/nst` | Separate inventory and gameplay windows; no unintended txAdmin TAB conflict; TAB/Escape/close releases NUI focus | Not run |
| Check 1280×720, 1920×1080 and ultrawide with small and large bags | Large readable panels dock right; no fullscreen opaque backdrop; all controls reachable, scrolling available when needed | Not run |
| Hold left mouse on an item, move, release | Preview follows the grabbed cell; one valid placement request; click alone only selects | Not run |
| Press R while holding a rectangular item | Footprint rotates; valid placement respects bounds and occupied cells | Not run |
| Release over occupied space or outside the bag | No item loss or invalid move; subsequent dragging and live updates still work | Not run |
| Cancel a drag by closing inventory or switching focus | No stuck drag state; reopening and subsequent snapshots work | Not run |
| Collect/drop/sell items while inventory stays open | Quantities, cash, weight and cells reflect committed state without reopening | Not run |
| Receive a state change during a held drag | Latest snapshot appears on release/cancel; stale placement is rejected safely without duplication | Not run |
| Loot common, rare and epic items of different sizes | Correct labels, colors, footprints and rotations; partial transfers conserve quantities | Not run |
| Fill bag by weight or geometry; change carrying equipment | Both limits enforced; smaller bag refused when contents cannot fit; legacy overflow remains recoverable | Not run |
| Buy, equip, fire, holster and drop pistol/rifle | Weapons and ammo occupy cells; authorized shot spends one round; no ammo means no shot; dropped weapon cannot remain usable | Not run |
| Full server restart with updater enabled and matching file baseline | Check completes before gameplay starts; verified update installs or current version starts unchanged | Not run |
| Test customized managed file, bad checksum and interrupted update on a disposable copy | Unsafe update rejected or recovered per updater rules; no partial gameplay startup or private-config overwrite | Not run |

The updater retains the managed file set introduced in v0.5.0. New resource files require a manual file-set upgrade; do not assume the updater can add arbitrary files. See [grid inventory](GRID_INVENTORY.md) for controls, constraints and firearm limitations.

## Two clients — NOT RUN

Prerequisites: two legitimate Enhanced clients with different accounts, a selected Enhanced server artifact, your own Cfx key, an isolated test database, and a local/private connection. Do not use older `-cl2` instructions without checking current Cfx documentation. The loopback example does not allow a second computer until the operator explicitly configures a private test network.

Record: date ___, testers A/B ___, GTA version ___, FiveM client version ___, server artifact/version/SHA256 ___, operating system ___, database name ___, revision before/after ___, console logs ___ .

| Step | A / B | Expected result | Actual |
|---|---|---|---|
| 1 | Both connect; open F6 and GPS | $500 per new account, English menu, working spawn and map locations | Not run |
| 2 | A starts a store robbery, leaves the zone, then returns | No reward; cooldown remains | Not run |
| 3 | A completes a robbery, then requests completion again | One physical loot drop with the configured assortment (default store: two watches and two phones); no automatic bag credit or duplicate reward | Not run |
| 4 | A sells to the fence; also tries from far away | Only a valid sale changes the balance | Not run |
| 5 | A creates a gang and invites B; B accepts | A member can deposit but cannot withdraw cash without the required role | Not run |
| 6 | A/B try taking the last stored item simultaneously | One item is transferred in total; no negative balances | Not run |
| 7 | B has no police role and tries to arrest A | Rejected; no sentence or equipment granted | Not run |
| 8 | B leaves the gang and goes on duty at the station | A baton and one service vehicle; role switching has a cooldown | Not run |
| 9 | A completes a depot robbery; B receives an alert | Tool consumed, police requirement enforced, correct timing and reward | Not run |
| 10 | A surrenders near B; B arrests A; A reconnects | Stolen goods, firearms and ammunition seized; remaining sentence preserved; cell works | Not run |
| 11 | A dies with inventory; both try to loot | One drop, 20 seconds of owner priority, then contested transfers never duplicate items | Not run |
| 12 | A respawns/reconnects while dead | 15-second wait; no extra death drops during spawn; 20-second protection with no combat during protection | Not run |
| 13 | A owns a hideout; B is a rival or police officer and raids it | 60-second warning, 60 seconds of presence, at most 25% loss (less with upgrades) | Not run |
| 14 | B disconnects during robbery/raid/combat | No reward; interruption and death loot follow the rules | Not run |
| 15 | A goes offline; B attempts a raid before/after 15 minutes | Protected before the threshold; raid allowed afterward | Not run |
| 16 | Rival gangs A/B are online; A captures a zone, B contests it | Continuous presence required; contesting resets progress | Not run |
| 17 | Administrator runs dryrun, then execute twice with the same key | Dryrun changes nothing; one wipe/backup/history entry; reconnect into the new season | Not run |
| 18 | Stop the resource during a copy of the test wipe; restart | Complete old or new season, never a partial or duplicate wipe | Not run |
| 19 | Restore a backup to a new test database and inspect it | Balance/storage/history match the backup; original unchanged | Not run |
| 20 | Disconnect the test database while A attempts to sell | Economy stops; no speculative gains; recovery uses persisted state | Not run |

Load tests with 16/32 clients, endurance testing, physical backups on a separate disk, and manual NUI inspection at different screen sizes remain acceptance work. Shorten timers only in a separate test configuration and restore them afterward.
