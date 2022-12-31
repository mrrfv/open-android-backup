#!/bin/bash

# we're using the Windows adb
export ADB_DIR=$(pwd)/windows-dependencies/adb/adb.exe

adb() {
     $ADB_DIR "$@"
}
export -f adb

bash ./backup.sh