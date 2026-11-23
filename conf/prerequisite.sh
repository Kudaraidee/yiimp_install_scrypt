#!/bin/bash
#####################################################
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by cryptopool.builders for crypto use...
# Modified by Xavatar / msy2008 / Kudaraidee
# Updated 2026: Ubuntu 22.04 and 24.04 only, PHP chosen per release
#####################################################

echo
echo
echo -e "$CYAN => Check prerequisite : $COL_RESET"
echo

if ! command -v lsb_release >/dev/null 2>&1; then
  echo -e "$RED lsb_release is missing. Install it with: sudo apt install lsb-release $COL_RESET"
  exit 1
fi

DISTRO=$(lsb_release -rs 2>/dev/null)

# Select the PHP version that matches the operating system release.
case "$DISTRO" in
  22.04)
    PHP_VER="8.2"
    ;;
  24.04)
    PHP_VER="8.3"
    ;;
  *)
    echo -e "$RED Aborting: this installer supports Ubuntu 22.04 and 24.04 only (detected: ${DISTRO:-unknown}). $COL_RESET"
    exit 1
    ;;
esac

export DISTRO PHP_VER

ARCHITECTURE=$(uname -m)
if [ "$ARCHITECTURE" != "x86_64" ]; then
  if [ -z "$ARM" ]; then
    echo -e "$RED Yiimp Install Script only supports x86_64 and will not work on any other architecture, like ARM or 32 bit OS. $COL_RESET"
    echo -e "$RED Your architecture is $ARCHITECTURE $COL_RESET"
    exit 1
  fi
fi

echo -e "$GREEN Ubuntu ${DISTRO} detected, PHP ${PHP_VER} will be installed. Done...$COL_RESET"
