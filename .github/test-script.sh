#!/bin/bash

adb shell mkdir -p /storage/emulated/0/open-android-backup-temp
adb shell touch /storage/emulated/0/open-android-backup-temp/SMS_Messages.csv

export unattended_mode="yes"
export archive_path="/tmp"
export archive_password="123"
export mode="Wired"
export TERM="xterm"
export CI="true"
export data_erase_choice="Fast"

# Backup
export selected_action="Backup"

# Hooks disabled,  ADB exporting method
export use_hooks="no"
export export_method="adb"
./backup.sh

# Hooks disabled, TAR exporting method
export use_hooks="no"
export export_method="tar"
./backup.sh

# Hooks enabled, ADB exporting method
export use_hooks="yes"
export export_method="adb"
cp .github/test-hook.sh ./hooks.sh
./backup.sh

# Hooks enabled, TAR exporting method
export use_hooks="yes"
export export_method="tar"
cp .github/test-hook.sh ./hooks.sh
./backup.sh
