#!/bin/bash
# ==============================================================================
# lid-sleep-daemon.sh
# Manages macOS clamshell sleep based on power source and user toggle.
# Must run with root privileges (managed by launchd).
# ==============================================================================

STATE_DIR="/Library/Application Support/LidSleepManager"
STATE_FILE="$STATE_DIR/enabled"
LOG_TAG="[LidSleepDaemon]"
LAST_APPLIED=""

# Ensure clean exit: revert to normal sleep behavior on stop/unload
cleanup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Stopping daemon. Reverting disablesleep to 0..."
    /usr/bin/pmset -a disablesleep 0
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Started Lid Sleep Manager daemon."

# Main monitor loop
while true; do
    ENABLED=0
    if [ -f "$STATE_FILE" ]; then
        CONTENT=$(/bin/cat "$STATE_FILE" 2>/dev/null | /usr/bin/tr -d '[:space:]')
        if [ "$CONTENT" = "1" ]; then
            ENABLED=1
        fi
    fi

    DESIRED=0
    if [ "$ENABLED" -eq 1 ]; then
        if /usr/bin/pmset -g batt | /usr/bin/grep -q "AC Power"; then
            DESIRED=1
        fi
    fi

    # Only apply pmset when state changes to avoid unnecessary writes
    if [ "$DESIRED" != "$LAST_APPLIED" ]; then
        /usr/bin/pmset -a disablesleep "$DESIRED"
        LAST_APPLIED="$DESIRED"
        echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Applied disablesleep=$DESIRED (UserEnabled=$ENABLED, AC=$([ "$DESIRED" -eq 1 ] && echo 'Yes' || echo 'No'))"
    fi

    sleep 3
done
