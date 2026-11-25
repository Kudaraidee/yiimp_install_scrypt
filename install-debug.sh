#!/bin/bash
################################################################################
# Debug launcher for the yiimp installer.
#
# The old install-debug.sh was a separate (very outdated) script for Ubuntu
# 16.04/18.04 with PHP 7.3. It is now a thin wrapper around install.sh so the
# debug run always uses the same, up-to-date installation code.
#
# Usage:  bash install-debug.sh
# Log:    install-debug.log (created in this directory, mode 0600)
#
# WARNING: bash -x and the log file contain generated passwords. Keep the log
#          private and delete it when you no longer need it.
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

LOG="$SCRIPT_DIR/install-debug.log"
umask 077
: > "$LOG" || exit 1

echo "Running install.sh with shell tracing. Output is also saved to $LOG"
echo "WARNING: the log contains generated passwords."

bash -x ./install.sh "$@" 2>&1 | tee -a "$LOG"
exit "${PIPESTATUS[0]}"
