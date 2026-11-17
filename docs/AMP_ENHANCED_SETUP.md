# FiveM Enhanced with txAdmin in AMP (Linux)

This standalone guide converts a **new, unconfigured AMP txAdmin instance** from the Legacy server package to FiveM for GTAV Enhanced. It does not require a particular game mode, framework or database.

The companion `tools` folder contains the two optional update scripts. Keep it with this guide when sharing the package. Requirements: SSH access with sudo, an AMP instance, and an Ubuntu/Debian x86_64 host with Bash, curl and xz-utils. The optional updater also requires jq and util-linux. No Python is required.

Example environment: Ubuntu x86_64, AMP account `amp`, instance `txAdmin01`, default instance location `/home/amp/.ampdata/instances/txAdmin01`.

The conversion has reached the Enhanced txAdmin setup page on this environment. A complete game connection has not yet been verified. The tested artifact includes txAdmin 9.0.0 beta.

## 1. Create and stop the AMP instance

Create a normal txAdmin instance in AMP and let its initial installation finish. Do not configure a game server or run a recipe yet.

Stop the application, then stop the **entire instance** from AMP's instance manager. Editing its configuration while AMP is running can cause your changes to be overwritten.

This guide is for a blank instance. If it already contains a configured server, stop here and plan a migration of its existing txData instead.

## 2. Download the Enhanced Linux package

Open https://docs.fivem.net/docs/server-download/ and select **FiveM for GTAV Enhanced**, **Linux**, and the recommended build if offered. Copy the download link.

Connect to the Linux host over SSH and run:

```bash
mkdir -p "$HOME/fivem-enhanced"
cd "$HOME/fivem-enhanced"

# Paste the official Enhanced Linux download URL at the prompt.
read -r -p 'Enhanced Linux download URL: ' DOWNLOAD_URL
curl --fail --location --output cfx-server_linux_x64.tar.xz "$DOWNLOAD_URL"

ENHANCED_DIR=$(mktemp -d "$HOME/fivem-enhanced/server-XXXXXX")
tar -xJf cfx-server_linux_x64.tar.xz -C "$ENHANCED_DIR"

test -f "$ENHANCED_DIR/alpine/opt/cfx-server/cfx-server" &&
test -f "$ENHANCED_DIR/alpine/lib/ld-musl-x86_64.so.1" &&
printf 'Enhanced package extracted: %s\n' "$ENHANCED_DIR"

cat "$ENHANCED_DIR/run.sh"
```

Continue in the same SSH session so that `ENHANCED_DIR` remains set. The commands below match the package whose `run.sh` uses `alpine/lib/ld-musl-x86_64.so.1`, the `alpine/lib/` and `alpine/usr/lib/` library directories, and `alpine/opt/cfx-server/cfx-server`. If a future package changes this layout, adapt the configuration before continuing.

## 3. Install beside Legacy and configure AMP

This creates a separate `server-enhanced` directory, backs up `GenericModule.kvp`, and preserves AMP's existing environment variables. It also sets a permanent data directory at `txadmin/txData`.

The standard template downloads Legacy artifacts, so this conversion initially disables its application update stages. Enable the Enhanced updater using the optional section below, or update the binaries manually.

Change the instance path in the first line if your instance has a different name or location:

```bash
INSTANCE=/home/amp/.ampdata/instances/txAdmin01

sudo bash -s -- "$INSTANCE" "$ENHANCED_DIR" <<'BASH'
set -euo pipefail
INSTANCE=$(realpath "$1")
SOURCE=$(realpath "$2")
CONFIG="$INSTANCE/GenericModule.kvp"
DEST="$INSTANCE/txadmin/server-enhanced"
DATA="$INSTANCE/txadmin/txData"
BACKUP="$CONFIG.before-enhanced-$(date +%Y%m%d-%H%M%S)"

test -f "$CONFIG"
test -d "$INSTANCE/txadmin/server-data"
test -f "$SOURCE/alpine/opt/cfx-server/cfx-server"
test -f "$SOURCE/alpine/lib/ld-musl-x86_64.so.1"

# Additional guard; stop the entire instance in AMP before running this.
if ps -eo args= | awk -v prefix="$INSTANCE/" 'index($0,prefix)==1 {found=1} END {exit !found}'; then
    echo 'STOP: instance processes still appear to be running.'
    exit 1
fi

if test -e "$DEST" || test -e "$DATA"; then
    echo 'STOP: destination already exists. Do not rerun or overwrite existing data.'
    exit 1
fi

for KEY in App.ExecutableLinux App.LinuxCommandLineArgs App.UpdateSources App.EnvironmentVariables; do
    test "$(grep -cF "$KEY=" "$CONFIG")" -eq 1
done

# Preserve the existing JSON environment object without needing Python or jq.
ENV_LINE=$(grep '^App.EnvironmentVariables=' "$CONFIG")
ENV_JSON=${ENV_LINE#App.EnvironmentVariables=}
ENV_JSON=${ENV_JSON%$'\r'}
[[ "$ENV_JSON" == \{*\} ]]
if [[ "$ENV_JSON" == *'"TXHOST_DATA_PATH"'* ]]; then
    echo 'STOP: a custom data path already exists; inspect it before migration.'
    exit 1
fi
ENV_BODY=${ENV_JSON%\}}
SEPARATOR=,
if [[ "$ENV_JSON" == '{}' ]]; then SEPARATOR=; fi
NEW_ENV="${ENV_BODY}${SEPARATOR}\"TXHOST_DATA_PATH\":\"${DATA}\"}"

cp -a "$CONFIG" "$BACKUP"
cmp --silent "$CONFIG" "$BACKUP"
OWNER=$(stat -c '%u:%g' "$INSTANCE/txadmin")
mkdir "$DEST" "$DATA"
cp -a "$SOURCE/." "$DEST/"
chown -R "$OWNER" "$DEST" "$DATA"
chmod 700 "$DATA"

sed -i \
  -e 's|^App.ExecutableLinux=.*|App.ExecutableLinux=server-enhanced/alpine/lib/ld-musl-x86_64.so.1|' \
  -e 's|^App.LinuxCommandLineArgs=.*|App.LinuxCommandLineArgs=--library-path "{{$FullBaseDir}}server-enhanced/alpine/lib/:{{$FullBaseDir}}server-enhanced/alpine/usr/lib/" -- "{{$FullBaseDir}}server-enhanced/alpine/opt/cfx-server/cfx-server" +set citizen_dir "{{$FullBaseDir}}server-enhanced/alpine/opt/cfx-server/citizen/"|' \
  -e 's|^App.UpdateSources=.*|App.UpdateSources=[]|' \
  "$CONFIG"

# Escape replacement metacharacters before inserting the preserved JSON.
ESCAPED_ENV=$(printf '%s' "$NEW_ENV" | sed 's/[\\&|]/\\&/g')
sed -i "s|^App.EnvironmentVariables=.*|App.EnvironmentVariables=$ESCAPED_ENV|" "$CONFIG"

echo "Configuration backup: $BACKUP"
echo "Permanent txAdmin data directory: $DATA"
echo 'Enhanced configuration installed. Start the instance in AMP.'
BASH
```

The **Update** button remains disabled until you install the optional updater below. Do not refresh the stock template or use **Reconfigure** to restore its settings: that can replace this custom configuration. AMP itself and game-server artifacts are separate updates.

## 4. Start and register txAdmin

Start the AMP instance, then start its application if necessary.

Open the URL printed by txAdmin, for example `http://SERVER_IP:40120/`, and register using the PIN shown in your own console.

Check the startup log: its profile directory should be under:

```text
/home/amp/.ampdata/instances/txAdmin01/txadmin/txData/
```

For a blank instance, first-time registration is expected. If you see `server-enhanced/txData` instead, stop and check `TXHOST_DATA_PATH` before deploying anything.

## 5. Configure your game server

Follow the txAdmin setup wizard and choose a recipe compatible with **FiveM for GTAV Enhanced**, or configure your own server data directory.

Enter your Cfx server license when requested. If your chosen recipe requires a database, provide its connection details and follow that recipe's installation instructions. A database is not required by this AMP conversion itself.

Keep server data and resources outside the `server-enhanced/alpine` binary directory. Use the permanent `txadmin/txData` location configured above for txAdmin's profile.

## 6. Verify

Confirm that the running process names `server-enhanced/alpine/opt/cfx-server/cfx-server`. Do not share complete process arguments publicly; they can contain txAdmin tokens.

Check the startup console for license authentication, resource startup errors and any checks required by your chosen framework or game mode.

From the gaming computer, open `http://SERVER_IP:30120/info.json`. A response confirms HTTP reachability, not a complete game connection. The configured game port also needs UDP connectivity.

In **FiveM for GTAV Enhanced**, open Browse Servers and enter:

```text
>SERVER_IP:30120
```

Use the actual server IP. Successful txAdmin startup alone does not verify game compatibility or multiplayer behavior.

## Rollback

Stop the application and the entire AMP instance. Restore `GenericModule.kvp` from the exact backup path printed in step 3, then start the instance again. The original Legacy binaries were not replaced. Keep the Enhanced data directory: do not delete it or assume a newer txAdmin profile can be downgraded safely.

## Optional: enable AMP's Update button for Enhanced

The companion files `tools/amp-update-enhanced.sh` and `tools/amp-enable-enhanced-updates.sh` replace the disabled update stages with an Enhanced-specific update operation. They do not change the current txData path or migrate a profile.

1. Upload both scripts to the `fivem-enhanced` directory in your SSH user's home folder using SCP or SFTP.
2. Install dependencies: `sudo apt-get install curl jq xz-utils util-linux`.
3. Stop the application and the entire `txAdmin01` AMP instance.
4. Install the update stage:

```bash
sudo bash "$HOME/fivem-enhanced/amp-enable-enhanced-updates.sh" \
  /home/amp/.ampdata/instances/txAdmin01
```

5. Start the AMP instance. Leave the txAdmin application stopped, then press **Update**. Start the application after the update completes.

The updater reads the Enhanced Linux download URL from the official Cfx download page. At verification time this was build 177; Enhanced had one offered build, not separate Recommended/Latest choices. The old AMP Server Build selector has no effect on this custom update stage.

The script validates the HTTPS download host, archive paths and expected package layout. It backs up and compares the installed server directory, and archives/verifies any txData directories in the three locations used by this setup (`txadmin/txData`, `txadmin/server/txData`, `txadmin/server-enhanced/txData`). If you use another data location, back it up separately before updating. The script replaces the Alpine binaries but leaves existing txData in place. It retains staging files and backups, so allow sufficient disk space and manage old backups after confirming a working update. MariaDB is not included in these file backups and is not modified by the updater itself.

If Cfx changes the page data format, download host or package layout, the script stops before replacing the installed binaries. It does not fall back to Legacy. Do not refresh/reconfigure the instance with the stock AMP template, as that can replace the custom configuration.

Validation: Bash syntax checks and live official download metadata inspection completed locally. Execution through AMP and a complete update/start cycle on Ubuntu still require verification. The URL marker prevents downloading the same version on subsequent updates; the first run may reinstall the existing build because the manual installation has no marker yet.

## References

- Cfx downloads: https://docs.fivem.net/docs/server-download/
- Enhanced differences: https://docs.fivem.net/docs/developers/legacy-vs-enhanced/
- txAdmin environment configuration: https://github.com/citizenfx/txAdmin/blob/master/docs/env-config.md
- AMP txAdmin template: https://github.com/CubeCoders/AMPTemplates/blob/main/txadmin.kvp
