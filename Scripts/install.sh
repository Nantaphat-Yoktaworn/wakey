#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (e.g., sudo ./Scripts/install.sh)"
  exit 1
fi

echo "==> Building Application..."
"$DIR/Scripts/build.sh"

echo "==> Installing App to /Applications..."
rm -rf /Applications/Wakey.app
cp -R "$DIR/build/Wakey.app" /Applications/

echo "==> Installing Daemon Script..."
mkdir -p /usr/local/bin
cp "$DIR/Daemon/lid-sleep-daemon.sh" /usr/local/bin/lid-sleep-daemon.sh
chmod +x /usr/local/bin/lid-sleep-daemon.sh

echo "==> Setting up State Directory..."
STATE_DIR="/Library/Application Support/LidSleepManager"
mkdir -p "$STATE_DIR"
chmod 777 "$STATE_DIR"

# Set default state to enabled (1) if not already set
if [ ! -f "$STATE_DIR/enabled" ]; then
    echo "1" > "$STATE_DIR/enabled"
fi
chmod 666 "$STATE_DIR/enabled"

echo "==> Installing LaunchDaemon..."
PLIST_DST="/Library/LaunchDaemons/com.lidsleepmanager.daemon.plist"

# Unload previous daemon if active
if launchctl list | grep -q "com.lidsleepmanager.daemon"; then
    echo "==> Unloading existing daemon..."
    launchctl unload -w "$PLIST_DST" 2>/dev/null || true
fi

cp "$DIR/Daemon/com.lidsleepmanager.daemon.plist" "$PLIST_DST"
chown root:wheel "$PLIST_DST"
chmod 644 "$PLIST_DST"

echo "==> Loading LaunchDaemon..."
launchctl load -w "$PLIST_DST"

echo ""
echo "=========================================================="
echo " Installation Complete!"
echo " - App installed: /Applications/Wakey.app"
echo " - Daemon running: com.lidsleepmanager.daemon"
echo " - State file: $STATE_DIR/enabled"
echo ""
echo " You can now launch the menu bar app by running:"
echo "   open /Applications/Wakey.app"
echo "=========================================================="
