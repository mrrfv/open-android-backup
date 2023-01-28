#!/bin/bash

adb shell mkdir -p /storage/emulated/0/linux-android-backup-temp

export unattended_mode="yes"
export selected_action="Backup"
export archive_path="/tmp"
export archive_password="123"
export mode="Wired"
export export_method="adb"
export use_hooks="no"
export TERM="nope"
export CI="true"

faketty() {
    script -qfc "$(printf "%q " "$@")" /dev/null
}

faketty ./backup.sh