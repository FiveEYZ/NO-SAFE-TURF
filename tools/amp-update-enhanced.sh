#!/usr/bin/env bash
# Run by AMP as its normal instance account, never as root.
set -euo pipefail
BASE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
ACTIVE="$BASE/server-enhanced"
for tool in curl jq tar flock; do command -v "$tool" >/dev/null || { echo "Missing dependency: $tool"; exit 1; }; done
test -d "$ACTIVE/alpine"
exec 9>"$BASE/.enhanced-update.lock"
flock -n 9 || { echo 'Another Enhanced update is running.'; exit 1; }
if ps -eo args= | awk -v prefix="$ACTIVE/" 'index($0,prefix)==1 {found=1} END {exit !found}'; then
    echo 'Stop the txAdmin application before updating.'; exit 1
fi
WORK=$(mktemp -d "$BASE/.enhanced-download-XXXXXX")
echo "Update workspace: $WORK"
curl --fail --location --proto '=https' --proto-redir '=https' --connect-timeout 20 --max-time 120 \
    'https://docs.fivem.net/docs/server-download/' -o "$WORK/page.html"
URL=$(jq -erRs 'capture("<script id=\"__NEXT_DATA__\"[^>]*>(?<data>.*?)</script>"; "s").data | fromjson | .props.pageProps.enhanced.linux[0].downloadURL | select(type == "string")' "$WORK/page.html")
if [[ ! "$URL" =~ ^https://cfx-downloads\.akamaized\.net/prod/[a-f0-9-]+/cfx-server_linux_x64\.tar\.xz$ ]]; then
    echo 'Unexpected Enhanced download metadata; installed files were not changed.'; exit 1
fi
if test -f "$ACTIVE/.enhanced-artifact-url" && [[ "$(cat "$ACTIVE/.enhanced-artifact-url")" == "$URL" ]]; then
    echo 'Already using the Enhanced artifact currently offered by Cfx.'; exit 0
fi
curl --fail --location --proto '=https' --proto-redir '=https' --connect-timeout 20 --max-time 900 \
    "$URL" -o "$WORK/artifact.tar.xz"
mkdir "$WORK/package"
tar -tJf "$WORK/artifact.tar.xz" > "$WORK/entries.txt"
if grep -Eq '(^/|(^|/)\.\.(/|$))' "$WORK/entries.txt"; then echo 'Unsafe archive paths.'; exit 1; fi
tar -xJf "$WORK/artifact.tar.xz" --no-same-owner -C "$WORK/package"
test -x "$WORK/package/alpine/lib/ld-musl-x86_64.so.1"
# The executable musl loader opens this file directly; an execute bit on
# cfx-server itself is not required by this launch method.
test -f "$WORK/package/alpine/opt/cfx-server/cfx-server"
test -r "$WORK/package/alpine/opt/cfx-server/cfx-server"
test -d "$WORK/package/alpine/opt/cfx-server/citizen"
# Refuse an unreviewed package layout instead of installing only part of it.
while IFS= read -r entry; do
    case "$entry" in alpine|run.sh|license-attribution.txt) ;; *) echo "Unexpected package entry: $entry"; exit 1;; esac
done < <(find "$WORK/package" -mindepth 1 -maxdepth 1 -printf '%f\n')

BACKUP=$(mktemp -d "$BASE/enhanced-backup-XXXXXX")
chmod 700 "$BACKUP"
echo "Backup directory: $BACKUP"
# Cover both the original implicit locations and the guide's explicit location.
for location in txData server/txData server-enhanced/txData; do
    if test -d "$BASE/$location"; then
        name=${location//\//-}
        tar -cJf "$BACKUP/$name.tar.xz" -C "$BASE" "$location"
        tar -dJf "$BACKUP/$name.tar.xz" -C "$BASE"
    fi
done
cp -a "$ACTIVE/." "$BACKUP/server-enhanced"
diff -qr "$ACTIVE" "$BACKUP/server-enhanced" >/dev/null
echo 'Backup verified. Installing Enhanced binaries; txData remains in place.'
mv "$ACTIVE/alpine" "$WORK/previous-alpine"
if ! mv "$WORK/package/alpine" "$ACTIVE/alpine"; then
    mv "$WORK/previous-alpine" "$ACTIVE/alpine"
    echo 'Installation failed; previous binaries restored.'; exit 1
fi
for file in run.sh license-attribution.txt; do
    if test -f "$WORK/package/$file"; then cp -a "$WORK/package/$file" "$ACTIVE/$file"; fi
done
printf '%s\n' "$URL" > "$ACTIVE/.enhanced-artifact-url"
echo "Installed: $URL"
echo 'Start the application in AMP and check the startup log. Backups and staging files are retained.'
