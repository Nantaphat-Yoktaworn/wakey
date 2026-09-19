#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (e.g., sudo ./Scripts/uninstall.sh)"
  exit 1
fi

echo "==> Stopping and unloading daemon..."
PLIST_DST="/Library/LaunchDaemons/com.lidsleepmanager.daemon.plist"
if [ -f "$PLIST_DST" ]; then
    launchctl unload -w "$PLIST_DST" 2>/dev/null || true
    rm -f "$PLIST_DST"
fi

echo "==> Terminating running processes..."
killall LidSleepManager 2>/dev/null || true
pkill -f lid-sleep-daemon.sh 2>/dev/null || true

echo "==> Restoring default macOS sleep behavior..."
/usr/bin/pmset -a disablesleep 0

echo "==> Removing installed files..."
rm -f /usr/local/bin/lid-sleep-daemon.sh
rm -rf "/Library/Application Support/LidSleepManager"
rm -rf /Applications/LidSleepManager.app
rm -f /var/log/lid-sleep-manager.log /var/log/lid-sleep-manager.err

echo ""
echo "=========================================================="
echo " Uninstallation Complete!"
echo " - Daemon removed."
echo " - App removed."
echo " - Normal macOS sleep behavior restored (disablesleep = 0)."
echo "=========================================================="
