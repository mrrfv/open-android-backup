#!/bin/bash

# This script is a workaround for the fact that WSL doesn't have direct access to Android devices.
# We're using the Windows adb executable to interact with the device, which runs on the Windows host.
# If we were to use the Linux adb, no devices would be detected.

export ADB_DIR=$(pwd)/windows-dependencies/adb/adb.exe

adb() {
     "$ADB_DIR" "$@"
}
export -f adb

bash ./backup.sh