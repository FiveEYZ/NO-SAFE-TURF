# Version 0.2 verification

Run node tests/run_node.js for JavaScript syntax, 209 weekly schedule deadlines and DST boundaries, bridge validation/startup/retry/failure handling, mocked FiveM callback dispatch and NUI DOM contracts.

On 2026-11-16, node tests/run_mariadb_node.js passed nine real MariaDB cases against a disposable 11.4.5 fixture: concurrent claims, entity/item persistence, changed-row writes, rollback, wipe preservation/idempotence, before/after-commit recovery, overdue wipes and backup/restore/corruption. It stopped its own server afterward and did not access deployment credentials.

The optional development regression runner python tests/run_local.py also passed 15 cases and all four Lua suites; ten legacy live database cases were skipped. Python is used only by these retained development tests, not by the deployed mod. Cfx native/export mocks do not prove actual server startup or runtime interoperability.

The older baseline results below remain reference evidence. Use the Node adapter and MariaDB for current installation.

# Verification and two-client test protocol

Run local checks with `python tests/run_local.py` from the project root. The latest complete run is documented below. Tests start temporary SQLite databases and a loopback HTTP server, never a public game server.

Last verified **2026-11-16**: the baseline run passed 15 Python test cases, four Lua suites, and one NUI/DOM suite; all resource Lua files compiled and frontend JavaScript passed syntax checks. Live MariaDB tests are intentionally skipped in that command. Separately, `python tests/run_mariadb.py` passed 11 cases against an isolated MariaDB 11.4.5 server (ten live database cases plus the shared validation case). Environment: Python 3.12.10, SQLite 3.49.1, PyMySQL 1.1.2, Lupa 2.6/Lua 5.4, tzdata 2025.2, Node 24.21.0. Windows sandbox access required elevated execution for temporary databases/local child processes; tests used isolated test data and loopback. Both child services were stopped afterward. No production environment was changed.

## Local automated tests

| Group | Verification |
|---|---|
| Python/SQLite/HTTP | Two concurrent claims: exactly one commit; stale revision/replay; API token; unauthorized season change; one-time wipe; persistent accounts/bans/history; failures before/after wipe commit; backup/restore; restore with a new schedule; Stockholm spring/autumn transitions |
| Real Lua → SQLite | Robbery start/tick/finish; persistence and duplicate-reward prevention; state retained after reopening the database |
| MariaDB + live service | Entity/item rows; unchanged-row trigger check; independent competing claims; real Lua robbery persistence/replay; failed transaction rollback; overdue wipe; persistent tables; wipe idempotence; before/after-commit failure injection; export/restore/hash corruption; actual service CLI HTTP 401/409 |
| gameplay_spec.lua | Robbery progress, time jumps, interruption, economy, distance, roles, atomic storage, raid locks, and rival-dependent territories |
| police_spec.lua | Role switching, arrest, sentences across reconnects, spawn protection, one-time death handling, a single looter, raid window/cooldown/loss, and limited offline protection |
| integration_spec.lua | Earned progression from starting cash through two store robberies, gang, hideout, depot, secured loot, raid, police, and death |
| adapter_spec.lua | Mocked FiveM natives/local storage export: startup, session IDs, authorization, failed commit without effects, healing after commit, server-observed death, and respawn |
| web_spec.js | Real frontend logic in a DOM mock: six tabs, action payloads, input/focus, text-based XSS-safe rendering, and network failures |

Wipe failures are simulated at three defined points and the database is reopened; this is not a physical power-loss test. DOM/native mocks are not browser or GTA playtests. Lua files also compile separately with Lua 5.4, and JavaScript syntax is checked with Node.

## Two clients — NOT RUN

Prerequisites: two legitimate Enhanced clients with different accounts, a selected Enhanced server artifact, your own Cfx key, an isolated test database, and a local/private connection. Do not use older `-cl2` instructions without checking current Cfx documentation. The loopback example does not allow a second computer until the operator explicitly configures a private test network.

Record: date ___, testers A/B ___, GTA version ___, FiveM client version ___, server artifact/version/SHA256 ___, operating system ___, database name ___, revision before/after ___, console logs ___ .

| Step | A / B | Expected result | Actual |
|---|---|---|---|
| 1 | Both connect; open F6 and GPS | $500 per new account, English menu, working spawn and map locations | Not run |
| 2 | A starts a store robbery, leaves the zone, then returns | No reward; cooldown remains | Not run |
| 3 | A completes a robbery, then requests completion again | Exactly six stolen goods, awarded once | Not run |
| 4 | A sells to the fence; also tries from far away | Only a valid sale changes the balance | Not run |
| 5 | A creates a gang and invites B; B accepts | A member can deposit but cannot withdraw cash without the required role | Not run |
| 6 | A/B try taking the last stored item simultaneously | One item is transferred in total; no negative balances | Not run |
| 7 | B has no police role and tries to arrest A | Rejected; no sentence or equipment granted | Not run |
| 8 | B leaves the gang and goes on duty at the station | A baton and one service vehicle; role switching has a cooldown | Not run |
| 9 | A completes a depot robbery; B receives an alert | Tool consumed, police requirement enforced, correct timing and reward | Not run |
| 10 | A surrenders near B; B arrests A; A reconnects | Stolen goods seized, remaining sentence preserved, cell works | Not run |
| 11 | A dies with inventory; both try to loot | One drop, 20 seconds of owner priority, then at most one successful looter | Not run |
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

