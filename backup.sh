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

function check_adb_connection() {
  echo "Please enable developer options on your device, connect it to your computer and set it to file transfer mode. Then, press Enter to continue."
  wait_for_enter
  adb devices > /dev/null
  echo "If you have connected your device correctly, you should now see a message asking for access to your phone. Allow it, then press Enter to go to the last step."
  wait_for_enter
  adb devices
  echo "Can you see your device in the list above, and does it say 'device' next to it? If not, quit this script (ctrl+c) and try again."
}

check_adb_connection

actions=( 'Backup' 'Restore' )
list_input "What do you want to do?" actions selected_action

if [ $selected_action = 'Backup' ]
then
  mkdir -p backup-tmp

  echo "Linux Android Backup will install a companion app on your device, which will allow for contacts to be backed up."
  echo "Downloading companion app"
  # -L makes curl follow redirects
  curl -L -o app-release.apk https://github.com/mrrfv/linux-android-backup/releases/download/latest/app-release.apk
  echo "Installing companion app"
  adb install -r app-release.apk

  echo "Please open the companion app, and press the 'Export Data' button. This will export contacts to the internal storage, allowing this script to backup them. Press Enter to continue."
  wait_for_enter

  # Export app list
  echo "Exporting installed app list."
  apps=$(adb shell pm list packages -3)
  apps=$(sed 's/package://g' <<< "$apps")
  echo $apps > backup-tmp/Apps.txt

  # Export contacts
  # TODO: This doesn't always work as expected (the companion app causes this, not the script itself)
  echo "Exporting contacts (as vCard)."
  adb pull /storage/emulated/0/linux-android-backup-temp ./backup-tmp/Contacts
  echo "Removing temporary files created by the companion app."
  adb shell rm -rfv /storage/emulated/0/linux-android-backup-temp

  # Export internal storage
  echo "Exporting internal storage - this will take a while."
  adb pull /storage/emulated/0 ./backup-tmp/Storage

  # Compress
  echo "Compressing & encrypting data - this will take a while."
  # -p: encrypt backup
  # -mhe=on: encrypt headers (metadata)
  # -mx=9: ultra compression
  # -bb3: verbose logging
  # -sdel: delete files after compression
  7z a -p -mhe=on -mx=9 -bb3 -sdel linux-android-backup-$(date +%m-%d-%Y-%H-%M-%S).7z backup-tmp/*

  echo "Backed up successfully."
  rm -rf backup-tmp > /dev/null
elif [ $selected_action = 'Restore' ]
then
  text_input "Please provide the location of the backup archive to restore (drag-n-drop):" archive_path

  echo "Extracting archive."
  7z e $archive_path -obackup-tmp

  # Restore applications
  apps=$(cat ./backup-tmp/apps.txt)
  separator=' ' read -r -a app_array <<< "$apps"
  for app in $apps; do
    clear
    echo "Step 1 of 3 - Restoring Apps"
    echo "Installing app: $app"
    adb shell am start -a android.intent.action.VIEW -d "market://details?id=$app" > /dev/null
    echo "Google Play Store has been opened on your device to install this app. Click the install button and press Enter to go to the next app."
    echo "If the app doesn't exist on the Play Store, ignore it."
    wait_for_enter
  done

  # Restore internal storage
  echo "Restoring internal storage."
  adb push ./backup-tmp/Storage /storage/emulated/0

  # Restore contacts
  echo "Restoring contacts."
  adb push ./backup-tmp/Contacts /storage/emulated/0/Contacts_Backup

  echo "Data restored - however, you need to manually import your contacts."
  echo "Open a File manager on your device, navigate to 'Contacts_Backup' and import each file."
fi
