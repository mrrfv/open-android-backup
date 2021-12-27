#!/bin/bash
set -e

# Load Inquirer.sh
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

PARENT_DIR=$(dirname "$DIR")
source $DIR/dist/list_input.sh
source $DIR/dist/text_input.sh
# ---

# Helper functions
function wait_for_enter() {
  read -p "" </dev/tty
}

# "cecho" makes output messages yellow
function cecho() {
  echo $(tput setaf 11)$1
}

function check_adb_connection() {
  cecho "Please enable developer options on your device, connect it to your computer and set it to file transfer mode. Then, press Enter to continue."
  wait_for_enter
  adb devices > /dev/null
  cecho "If you have connected your device correctly, you should now see a message asking for access to your phone. Allow it, then press Enter to go to the last step."
  wait_for_enter
  adb devices
  cecho "Can you see your device in the list above, and does it say 'device' next to it? If not, quit this script (ctrl+c) and try again."
}
# ---

check_adb_connection

actions=( 'Backup' 'Restore' )
list_input "What do you want to do?" actions selected_action

# The companion app is required regardless of whether we're backing up the device or not,
# so we're installing it before the if statement
cecho "Linux Android Backup will install a companion app on your device, which will allow for contacts to be backed up and restored."
cecho "The companion app is open-source, and you can see what it's doing under the hood on GitHub."
if [ ! -f linux-android-backup-companion.apk ]; then
  cecho "Downloading companion app."
  # -L makes curl follow redirects
  curl -L -o linux-android-backup-companion.apk https://github.com/mrrfv/linux-android-backup/releases/download/latest/app-release.apk
else
  cecho "Companion app already downloaded."
fi
cecho "Installing companion app."
adb install -r linux-android-backup-companion.apk

if [ $selected_action = 'Backup' ]
then
  mkdir -p backup-tmp/

  adb shell am start -n com.example.companion_app/.MainActivity
  cecho "The companion app has been opened on your device. Please press the 'Export Data' button - this will export contacts to the internal storage, allowing this script to backup them. Press Enter to continue."
  wait_for_enter

  # Export apps (.apk files)
  cecho "Exporting apps."
  mkdir -p backup-tmp/Apps
  for app in $(adb shell pm list packages -3 -f)
  do
    declare output=backup-tmp/Apps/$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM/ # There's a better way to do this, but I'm lazy
    mkdir -p $output
    cecho $( cecho $app | sed "s/package://" | sed "s/base.apk=/base.apk /" | sed "s/\([[:blank:]]\).*/\1/").apk $output
  done

  # Export contacts
  cecho "Exporting contacts (as vCard)."
  adb pull /storage/emulated/0/linux-android-backup-temp ./backup-tmp/Contacts
  cecho "Removing temporary files created by the companion app."
  adb shell rm -rfv /storage/emulated/0/linux-android-backup-temp

  # Export internal storage
  cecho "Exporting internal storage - this will take a while."
  adb pull /storage/emulated/0 ./backup-tmp/Storage

  # Compress
  cecho "Compressing & encrypting data - this will take a while."
  # -p: encrypt backup
  # -mhe=on: encrypt headers (metadata)
  # -mx=9: ultra compression
  # -bb3: verbose logging
  # -sdel: delete files after compression
  7z a -p -mhe=on -mx=9 -bb3 -sdel linux-android-backup-$(date +%m-%d-%Y-%H-%M-%S).7z backup-tmp/*

  cecho "Backed up successfully."
  rm -rf backup-tmp > /dev/null
elif [ $selected_action = 'Restore' ]
then
  text_input "Please provide the location of the backup archive to restore (drag-n-drop):" archive_path

  cecho "Extracting archive."
  7z e $archive_path -obackup-tmp

  # Restore applications
  cecho "Restoring applications."
  # We don't want a single app to break the whole script
  set +e
  for file in ./backup-tmp/Apps/**/*.apk; do
    cecho "Installing app: $file"
    adb install $file
  done
  set -e

  # Restore internal storage
  cecho "Restoring internal storage."
  adb push ./backup-tmp/Storage /storage/emulated/0

  # Restore contacts
  cecho "Pushing backed up contacts to device."
  adb push ./backup-tmp/Contacts /storage/emulated/0/Contacts_Backup

  cecho "Data restored!"
  cecho "If this script helped you, then don't forget to star the GitHub repository. It helps a lot."
  cecho "WARNING: Contacts have been only copied to your device. You need to open the companion app to restore them."
fi
