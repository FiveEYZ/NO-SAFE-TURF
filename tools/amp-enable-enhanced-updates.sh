#!/usr/bin/env bash
# Install once over SSH with the entire AMP instance stopped.
set -Eeuo pipefail
trap 'echo "ERROR: installation stopped at line $LINENO (exit $?). No server was started." >&2' ERR
fail() { echo "ERROR: $*" >&2; exit 1; }
test "$(id -u)" -eq 0 || { echo 'Run this installer using sudo bash.'; exit 1; }
INSTANCE=$(realpath "${1:?Usage: installer INSTANCE_PATH}")
SOURCE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
BASE="$INSTANCE/txadmin"
CONFIG="$INSTANCE/GenericModule.kvp"
command -v jq >/dev/null || { echo 'Install jq first: sudo apt-get install jq'; exit 1; }
test -f "$CONFIG" || fail 'GenericModule.kvp was not found at the supplied instance path.'
test -f "$SOURCE/amp-update-enhanced.sh" || fail 'Place BOTH installer and updater scripts in the same directory.'
test -f "$BASE/server-enhanced/alpine/opt/cfx-server/cfx-server" && test -r "$BASE/server-enhanced/alpine/opt/cfx-server/cfx-server" || fail 'Enhanced server file is missing or unreadable.'
test -x "$BASE/server-enhanced/alpine/lib/ld-musl-x86_64.so.1" || fail 'Enhanced musl loader is missing or not executable.'
# AMP can save KVP files with CRLF endings. Ignore only the trailing CR.
EXECUTABLE=$(sed -n 's/^App.ExecutableLinux=//p' "$CONFIG" | tr -d '\r')
[[ "$EXECUTABLE" == 'server-enhanced/alpine/lib/ld-musl-x86_64.so.1' ]] || fail 'App.ExecutableLinux does not match the Enhanced conversion guide.'
COUNT=$(grep -c '^App.UpdateSources=' "$CONFIG" || true)
[[ "$COUNT" == 1 ]] || fail 'Expected exactly one App.UpdateSources setting.'
if ps -eo args= | awk -v prefix="$INSTANCE/" 'index($0,prefix)==1 {found=1} END {exit !found}'; then
    echo 'Stop the entire AMP instance before installing.'; exit 1
fi
BACKUP=$(mktemp -d "$INSTANCE/enhanced-updater-config-XXXXXX")
chmod 700 "$BACKUP"
cp -a "$CONFIG" "$BACKUP/GenericModule.kvp"
cmp --silent "$CONFIG" "$BACKUP/GenericModule.kvp"
if test -f "$BASE/amp-update-enhanced.sh"; then cp -a "$BASE/amp-update-enhanced.sh" "$BACKUP/"; fi
sed 's/\r$//' "$SOURCE/amp-update-enhanced.sh" > "$BACKUP/updater-normalized.sh"
bash -n "$BACKUP/updater-normalized.sh"
install -m 755 "$BACKUP/updater-normalized.sh" "$BASE/amp-update-enhanced.sh"
chown --reference="$BASE" "$BASE/amp-update-enhanced.sh"
STAGES=$(jq -cn '[{UpdateStageName:"Update FiveM Enhanced from Cfx",UpdateSourcePlatform:2,UpdateSource:8,UpdateSourceArch:3,UpdateSourceData:"/bin/bash",UpdateSourceArgs:"\"{{$FullBaseDir}}amp-update-enhanced.sh\"",SkipOnFailure:false,RunInBackground:false} ]')
TEMP=$(mktemp "$INSTANCE/.enhanced-config-XXXXXX")
STAGES="$STAGES" awk '/^App.UpdateSources=/ {print "App.UpdateSources=" ENVIRON["STAGES"]; next} {print}' "$CONFIG" > "$TEMP"
# Validate the serialized stage before replacing the settings.
sed -n 's/^App.UpdateSources=//p' "$TEMP" | jq -e 'length == 1 and .[0].UpdateSource == 8' >/dev/null
chmod --reference="$CONFIG" "$TEMP"
chown --reference="$CONFIG" "$TEMP"
mv "$TEMP" "$CONFIG"
echo "Installed. Configuration backup: $BACKUP"
echo 'Restart the AMP instance. Stop its txAdmin application before pressing Update.'
