#!/bin/bash
# ==============================================================================
# lid-sleep-daemon.sh
# Manages macOS clamshell sleep based on power source, lid state, and user toggle.
# Must run with root privileges (managed by launchd).
# ==============================================================================

STATE_DIR="/Library/Application Support/LidSleepManager"
STATE_FILE="$STATE_DIR/enabled"
LOG_TAG="[LidSleepDaemon]"

LAST_APPLIED=""

# Ensure clean exit: revert to factory macOS power management settings
cleanup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Stopping daemon. Reverting power settings..."
    /usr/bin/pmset -a disablesleep 0
    /usr/bin/pmset -c womp 1
    /usr/bin/pmset -c sleep 0
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Started Wakey daemon."

while true; do
    # 1. Read user toggle (1 = enabled, 0 = disabled)
    ENABLED=0
    if [ -f "$STATE_FILE" ]; then
        CONTENT=$(/usr/bin/tr -d '[:space:]' < "$STATE_FILE" 2>/dev/null)
        if [ "$CONTENT" = "1" ]; then
            ENABLED=1
        fi
    fi

    # 2. Check AC power connection (1 = on AC, 0 = on battery)
    ON_AC=0
    if /usr/bin/pmset -g batt | /usr/bin/grep -q "AC Power"; then
        ON_AC=1
    fi

    # 3. Check physical lid clamshell state (1 = lid closed, 0 = lid open)
    LID_CLOSED=0
    if /usr/sbin/ioreg -r -k AppleClamshellState -d 1 2>/dev/null | /usr/bin/grep -q '"AppleClamshellState" = Yes'; then
        LID_CLOSED=1
    fi

    # Keep awake only when user enabled the feature AND is on AC power
    DESIRED=0
    if [ "$ENABLED" -eq 1 ] && [ "$ON_AC" -eq 1 ]; then
        DESIRED=1
    fi

    # Apply power settings whenever desired state transitions
    if [ "$DESIRED" != "$LAST_APPLIED" ]; then
        if [ "$DESIRED" -eq 1 ]; then
            # ACTIVE: Keep awake on AC, allow network wake (SSH)
            /usr/bin/pmset -a disablesleep 1
            /usr/bin/pmset -c womp 1
            /usr/bin/pmset -c sleep 0
        else
            # INACTIVE: Normal sleep, disable network wake on AC so incoming SSH won't wake a sleeping Mac
            /usr/bin/pmset -a disablesleep 0
            /usr/bin/pmset -c womp 0
            /usr/bin/pmset -c sleep 1
        fi
        LAST_APPLIED="$DESIRED"
        SLEEP_VAL=$((1 - DESIRED))
        echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Applied: disablesleep=$DESIRED, womp=$DESIRED, sleep=$SLEEP_VAL (Enabled=$ENABLED, AC=$ON_AC, LidClosed=$LID_CLOSED)"
    fi

    # Enforce immediate sleep if lid is closed and keep-awake is inactive
    if [ "$LID_CLOSED" -eq 1 ] && [ "$DESIRED" -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Lid closed with keep-awake inactive (AC=$ON_AC, Enabled=$ENABLED). Enforcing immediate sleep..."
        /usr/bin/pmset sleepnow
    fi

    sleep 2
done
