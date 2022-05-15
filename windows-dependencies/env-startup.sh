#!/bin/bash
export ADB_DIR=$(pwd)/windows-dependencies/adb.exe

adb() {
     $ADB_DIR "$@"
}
export -f adb

bash ./backup.sh