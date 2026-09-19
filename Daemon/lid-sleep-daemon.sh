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
LAST_LID_STATE=""
LAST_AC_STATE=""
LAST_ENABLED_STATE=""

# Ensure clean exit: revert to normal sleep behavior on stop/unload
cleanup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Stopping daemon. Reverting disablesleep to 0..."
    /usr/bin/pmset -a disablesleep 0
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Started Wakey daemon."

while true; do
    # 1. Read user toggle (1 = enabled, 0 = disabled)
    ENABLED=0
    if [ -f "$STATE_FILE" ]; then
        CONTENT=$(/bin/cat "$STATE_FILE" 2>/dev/null | /usr/bin/tr -d '[:space:]')
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

    # We only disable sleep when user enabled the feature AND is on AC power
    DESIRED=0
    if [ "$ENABLED" -eq 1 ] && [ "$ON_AC" -eq 1 ]; then
        DESIRED=1
    fi

    # Apply disablesleep if changed
    if [ "$DESIRED" != "$LAST_APPLIED" ]; then
        /usr/bin/pmset -a disablesleep "$DESIRED"
        LAST_APPLIED="$DESIRED"
        echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Applied disablesleep=$DESIRED (Enabled=$ENABLED, AC=$ON_AC, LidClosed=$LID_CLOSED)"
    fi

    # Enforce sleep when lid is closed and sleep should NOT be prevented (DESIRED=0):
    # This covers:
    #   Case A: User unplugged AC while lid was already closed (ON_AC went from 1 to 0).
    #   Case B: User closed lid while option is disabled or on battery (LID_CLOSED went from 0 to 1).
    #   Case C: User toggled option to OFF while lid was closed on AC (ENABLED went from 1 to 0).
    if [ "$LID_CLOSED" -eq 1 ] && [ "$DESIRED" -eq 0 ]; then
        if [ "$LAST_LID_STATE" != "1" ] || [ "$LAST_AC_STATE" = "1" ] || [ "$LAST_ENABLED_STATE" = "1" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Lid closed with keep-awake inactive (AC=$ON_AC, Enabled=$ENABLED). Enforcing immediate sleep..."
            /usr/bin/pmset sleepnow
        fi
    fi

    LAST_LID_STATE="$LID_CLOSED"
    LAST_AC_STATE="$ON_AC"
    LAST_ENABLED_STATE="$ENABLED"

    sleep 2
done
