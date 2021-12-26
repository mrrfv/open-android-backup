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
  mkdir -p backup-tmp/

  echo "Linux Android Backup will install a companion app on your device, which will allow for contacts to be backed up."
  echo "Downloading companion app"
  # -L makes curl follow redirects
  curl -L -o app-release.apk https://github.com/mrrfv/linux-android-backup/releases/download/latest/app-release.apk
  echo "Installing companion app"
  adb install -r app-release.apk

  echo "Please open the companion app, and press the 'Export Data' button. This will export contacts to the internal storage, allowing this script to backup them. Press Enter to continue."
  wait_for_enter

  echo "Uninstalling companion app."
  adb uninstall com.example.companion_app

  # Export apps (.apk files)
  echo "Exporting apps."
  mkdir backup-tmp/Apps
  for app in $(adb shell pm list packages -3 -f)
  do
    adb pull $( echo $app | sed "s/^package://" | sed "s/base.apk=/base.apk /").apk backup-tmp/Apps/$RANDOM$RANDOM$RANDOM.apk
  done

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
  echo "Restoring applications."
  # We don't want a single app to break the whole script
  set +e
  for file in ./backup-tmp/Apps; do
    echo "Installing app: $file"
    adb install $file
  done
  set -e

  # Restore internal storage
  echo "Restoring internal storage."
  adb push ./backup-tmp/Storage /storage/emulated/0

  # Restore contacts
  echo "Restoring contacts."
  adb push ./backup-tmp/Contacts /storage/emulated/0/Contacts_Backup

  echo "Attempting to auto-restore contacts. Please check your device and see if it's asking for confirmation (if it's requesting confirmation multiple times, that's normal)."
  for file in ./backup-tmp/Contacts; do
    adb shell am start -t "text/x-vcard" -d "file:///storage/emulated/0/Contacts_Backup/$file" -a android.intent.action.VIEW com.android.contacts
  done

  echo "Data restored!"
  echo "If this script helped you, then don't forget to star the GitHub repository. It helps a lot."
  echo "Warning: The automatic restoration of contacts might not work on every device. If your contacts have not been restored, open a file manager, navigate to 'Contacts_Backup' and import the vCard files manually."
fi
