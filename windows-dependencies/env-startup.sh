#!/bin/bash

# we're using the Windows adb because WSL doesn't have direct access to the Android device
# (if we were to use the Linux adb, no devices would be detected)
export ADB_DIR=$(pwd)/windows-dependencies/adb/adb.exe

adb() {
     "$ADB_DIR" "$@"
}
export -f adb

bash ./backup.sh