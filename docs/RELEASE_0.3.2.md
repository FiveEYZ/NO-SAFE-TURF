# v0.3.2 — Wait for oxmysql readiness

The first storage request could run before oxmysql finished connecting. Connection acquisition now polls readiness for up to ten seconds before returning an unavailable result. It respects resource shutdown and never retries queries, transactions or uncertain writes.

Validation: JavaScript checks and five Lua suites pass, including delayed readiness, timeout and shutdown while waiting. Actual Enhanced startup with this patch still requires verification.

Existing v0.3.1 installations can replace only no_safe_turf/server/storage/oxmysql.js and restart no_safe_turf. No schema change, reinstall or data reset is required. Fresh installs use the updated recipe and matching asset.

The operator's v0.3.1 log confirms Enhanced resources started and MariaDB connected. Filesystem permission diagnostics, public server-list reachability and the deprecated ScheduleResourceTick notice are not resolved by this patch.
