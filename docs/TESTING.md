# Verification protocol · 0.3.0

Verified locally on 2026-11-16:

- npm test passes JavaScript syntax, 209 weekly deadlines/DST checks, private URL/config conversion, oxmysql transaction acknowledgement/rollback/shutdown contracts, storage bridge validation/retry, NUI DOM checks and recipe structure.
- Five Lua 5.4 suites pass under Wasmoon: gameplay, police, full earned-progression chain, adapter and client focus. Locale scripts load in manifest order. Adapter checks include a lost commit response plus failed reconciliation read, delayed recovery of respawn, lost scheduled-wipe response, trusted txAdmin revive and rejected untrusted heal events.
- npm run test:database passes 15 cases on disposable MariaDB 11.4.5. Includes first-install guard, initial metadata protection, concurrent item claims, changed-row writes, actual SQL rollback, killed database connection and reconnect, backup failure blocking manual/scheduled wipe, real on-disk archive restore, hash corruption rejection, wipe idempotence and failure around commit. The oxmysql contract test uses a proxy implementing the pinned export contract over real MariaDB; it does not run the Cfx export boundary.
- node tests/recipe_spec.js --files replays recipe file operations using the built local ZIP and downloaded pinned upstream archives. It verifies hashes, paths, start order, documented placeholders and dbDelete=false. It does not launch txAdmin, fetch the unpublished mod release or execute recipe SQL against a remote server.
- tools/package.ps1 screens credentials and excludes private files, archives, Python and test data. All runtime frontend files are already built.

Environment: Node 24.21.0; embedded runtime target Node 22; Wasmoon 1.16.0/Lua 5.4; YAML 2.8.1; mysql2 3.14.1 for offline tests; oxmysql runtime pin 2.14.3. No Python command is used by the maintained test/build/install paths. Root npm ci --ignore-scripts prepares tests; resource npm ci --omit=dev --ignore-scripts prepares offline tools.

Disposable database binaries are optional developer fixtures, not deployment dependencies. .testdata holds artifacts and the child database processes are stopped. The downloaded MariaDB 11.4.5 Windows fixture SHA256 is b7c11d38657f16b837e68199d73670510aadb78f42dfa5d5fdea31a7aab342e3. Use a current patched MariaDB for hosting.

## Outstanding deployment acceptance

- Actual Cfx resource startup and cross-resource Promise/native behavior.
- External MariaDB host, grants, TLS certificate validation and network interruption behavior.
- Clean txAdmin Server Deployer run against reachable recipe/release URLs.
- txAdmin heal/revive, teleport, kick/shutdown and focus behavior with real clients.
- Real hosting filesystem backup write/readback and off-host restore rehearsal.
- Two-client Enhanced protocol, native coordinates/models, NUI rendering and 16/32-player load/endurance testing.
- Physical power-loss durability.

The prepared main-branch recipe and v0.3.0 asset URLs returned HTTP 404 on 2026-11-16. No publication or production change was made. A server key, correct server/client artifacts, two licensed clients, a fresh test database and reachable approved release are needed for the remaining acceptance work.

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
