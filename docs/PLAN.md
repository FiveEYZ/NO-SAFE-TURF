# Architecture and delivery plan · 0.3.0

Continue the existing project; retain standalone Lua rules and prebuilt NUI. Runtime data access now uses pinned oxmysql 2.14.3 through a server-local JavaScript adapter. MariaDB v1 schema, per-entity/item rows and global revision lock are preserved. No destructive schema migration is required by this update.

## Implemented requirement changes

1. Added AGENTS.md and explicit ownership. Three Sol High agents handled gameplay, police and infrastructure; usage limits interrupted them. Lead completed integration. Astra High reviewed critical code; Luna Medium handled bounded documentation.
2. Moved runtime database access to the maintained oxmysql resource, retained mysql2 only for offline tools/tests, validated txAdmin URL handoff and added startup ordering.
3. Made verified, synced filesystem archives a condition for wipe. Backup failure aborts SQL reset; real archive restore and connection loss/reconnection are tested.
4. Added English locale files for Lua and storage messages, preserved built NUI and blocked opening over another NUI's focus.
5. Added trusted txAdmin revive and administrative-disconnect handling; fixed delayed reconciliation of committed respawn/wipe effects.
6. Added membership cooldown, opaque new gang IDs, online-defender territory rules and one score award per gang/zone/season.
7. Replaced maintained Python tests with Node/Wasmoon Lua 5.4. Locked and downloaded recipe dependencies; prepared release and English operations/upgrade instructions.

## Interfaces

NST.handlers[action](state,context,args) are non-yielding authoritative transitions. Context identity/time/position/police count comes from server observation. A state copy is published only after persistence. Client input cannot supply balances, rewards or privileges.

Storage uses revision/state/nextWipe envelopes and local server exports only. An uncertain write outcome is reloaded before accepting another state; persisted serial effects are reconciled against the previous envelope. Wipes hold the database metadata lock, require verified archive creation and atomically commit season/history/ledger changes.

## Remaining acceptance

All independent local implementation and test preparation is complete. Do not claim actual runtime acceptance: reachable approved publication, a selected Enhanced artifact/key, fresh external test database and two licensed clients are required to run txAdmin deployment, TLS/grants, Cfx export/native tests and gameplay. Capacity remains a 16–32-player target requiring profiling.

Sources, exact checks and limitations are in COMPATIBILITY.md, TESTING.md, REQUIREMENTS.md and LIMITATIONS.md. Source ownership and test commands are maintained in ../AGENTS.md.
