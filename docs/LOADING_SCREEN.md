# Loading screen — v0.5.0

A self-contained animated city-grid loading screen with radar sweep, NO SAFE TURF typography, rotating English tips and actual FiveM loadProgress events. No audio, remote assets, web fonts or CDN dependencies. Reduced-motion preferences disable animation. FiveM controls the loading screen lifetime automatically; no manual shutdown or new spawn dependency is introduced.

## Upgrade from v0.4.0

This release adds three files. The v0.4.0 updater deliberately refuses changes to its managed file set, so this is a manual upgrade. The automatic feed remains on v0.4.0 until a compatible follow-up release is available.

1. Stop the server application in txAdmin and back up your no_safe_turf resource.
2. Download the v0.5.0 prebuilt release ZIP.
3. Copy `resource/web/loading.html`, `loading.css` and `loading.js` into your installed `no_safe_turf/web/` directory.
4. Replace `no_safe_turf/fxmanifest.lua` and `no_safe_turf/update-state.json` with the matching files from that same ZIP. This assumes your installed code is the unchanged v0.4.0 release; otherwise merge your changes manually and keep automatic updates disabled.
5. Preserve shared/config.lua, server.cfg, credentials and database. No SQL changes are required.
6. Start the server and reconnect. A loading screen appears during a new connection, not when restarting the resource for an already connected player.

Fresh installations using recipe.yaml include the screen. You can preview loading.html in a browser; it displays CONNECTING until FiveM supplies real loading progress. 100% means the reported asset progress is complete, not that spawning has finished.

Local JavaScript/Lua checks pass. Actual rendering and dismissal in FiveM Enhanced must be confirmed in-game.

Reference: https://docs.fivem.net/docs/scripting-manual/nui-development/loading-screens/
