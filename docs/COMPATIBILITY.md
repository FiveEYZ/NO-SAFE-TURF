# Compatibility review — 2026-11-16

Official sources were checked before implementation. GTA V Enhanced has a dedicated FiveM client and dedicated server artifacts. Install Rockstar Games Launcher and GTA V Enhanced before the client, following [Cfx installation instructions](https://support.cfx.re/hc/en-us/articles/27623908811164-Downloading-and-installing-FiveM-for-GTAV-Enhanced). The [server onboarding guide](https://docs.fivem.net/docs/server-manual/onboarding-guide-fivem-for-gtav-enhanced/) links the correct server download and specifies the Visual C++ Redistributable.

The [Cfx Enhanced change list](https://docs.fivem.net/docs/developers/legacy-vs-enhanced/) describes reused server IDs, mandatory NUI callback strict mode, big-mode-only OneSync, a changed server filename, and limited gamebuild support. We use license identity and session checks, NUI requests to the resource itself, and no fixed Legacy build numbers. The Enhanced server executable is named `cfx-server.exe`. The reviewed documentation still describes Early Access limitations.

The resource uses Lua, NUI, and base game models, with no imported streamed maps/models, escrow, or .NET code. Legacy assets are not assumed to work. [Cfx discusses script compatibility and asset conversion separately](https://forum.cfx.re/t/development-update-fivem-for-gtav-enhanced/5391635). This documentation supports the architecture choice; it does not prove this resource has been playtested.

Download the Enhanced artifact from the [official server download page](https://docs.fivem.net/docs/server-download/), not an archived Legacy link. The dynamic download page did not expose an unambiguously selected Enhanced version number in its text view, so no number was invented. Before deployment approval, the operator must record the artifact version and SHA256 together with client and GTA versions in the two-client protocol. Repeat the test matrix after updates.

Security principles follow [Secure Your Events](https://docs.fivem.net/docs/developers/server-security/): the server chooses rewards and checks position, role, and state. Native positions are network-replicated and do not replace anticheat or movement analysis. Five Lua suites run locally in Lua 5.4, but native calls, resource startup, and rendering in Enhanced must be verified there.

## Dependencies and rights

| Component | Version/selection | License/rights | Locally verified |
|---|---|---|---|
| Project code, NUI/CSS | 0.3.0 | MIT, LICENSE | Yes, tests; not in-game rendering |
| MariaDB backend | 10.11+ required; isolated 11.4.5 test fixture | MariaDB Server GPLv2; server not bundled with the mod | Yes, isolated database tests; not the deployment host |
| Wasmoon, development tests | 1.16.0, Lua 5.4 | MIT; Lua MIT | Yes |
| Node, embedded server runtime and offline tools | Embedded 22 selected; standalone 24.21.0 tested | MIT and bundled third-party licenses | Yes |
| FiveM Enhanced server/client | Current Enhanced artifact selected by operator | Cfx/Rockstar Platform License Agreement | No |
| mapmanager/sessionmanager/spawnmanager | Versions provided by the selected Basic Server installation | Respective Cfx package terms; not bundled | No |
| GTA V Enhanced | Licensed installation required | Rockstar terms of use | No |

No ROB RUN files, images, music, brand artwork, or other third-party assets are copied. GTA models are referenced in the licensed game installation and are not distributed. System fonts are used; there are no CDN or font dependencies.

For self-hosted txAdmin/MariaDB installation, see [MARIADB.md](MARIADB.md). Runtime uses oxmysql 2.14.3 (LGPL-3.0-or-later) with FiveM embedded Node 22. mysql2 3.14.1 (MIT) is bundled for offline tools/tests. Python/Lupa are retired reference tools and excluded from maintained checks and release. Native compatibility and Lua/JavaScript exports require the Enhanced two-client test. See [Cfx JavaScript runtime](https://docs.fivem.net/docs/scripting-manual/runtimes/javascript/) for Node 22 and main-thread callback requirements.

Runtime database resource: oxmysql 2.14.3, LGPL-3.0-or-later, downloaded release verified (see TXADMIN_RECIPE.md). Its manifest requires server artifact 12913+, Node 22; this does not replace selecting an Enhanced artifact. Root developer dependency YAML 2.8.1 uses ISC. Transitive versions are locked in package-lock.json and resource/package-lock.json; distributed node_modules retains its upstream license files. No paid resource is required.
