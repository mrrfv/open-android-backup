#!/bin/bash

adb shell mkdir -p /storage/emulated/0/linux-android-backup-temp

export unattended_mode="yes"
export selected_action="Backup"
export archive_path="/tmp"
export archive_password="123"
export CI="true"

./backup.sh