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
source $DIR/inquirer-sh/list_input.sh
source $DIR/inquirer-sh/text_input.sh
# ---

# Helper functions
function wait_for_enter() {
  if [ ! -v unattended_mode ]; then
    read -p "" </dev/tty
  else
    sleep 10s
  fi
}

# "cecho" makes output messages yellow
function cecho() {
  echo $(tput setaf 11)$1$(tput init)
}

function check_adb_connection() {
  cecho "Please enable developer options on your device, connect it to your computer and set it to file transfer mode. Then, press Enter to continue."
  wait_for_enter
  adb devices > /dev/null
  cecho "If you have connected your device correctly, you should now see a message asking for access to your phone. Allow it, then press Enter to go to the last step."
  cecho "Tip: If this is not the first time you're using this script, you might not need to allow anything."
  wait_for_enter
  adb devices
  cecho "Can you see your device in the list above, and does it say 'device' next to it? If not, quit this script (ctrl+c) and try again."
}

function uninstall_companion_app() {
  cecho "Attempting to uninstall companion app."
  {
    set +e
    adb uninstall com.example.companion_app
    set -e
  } &> /dev/null
}
# ---

check_adb_connection

if [ ! -v selected_action ]; then
  actions=( 'Backup' 'Restore' )
  list_input "What do you want to do?" actions selected_action
fi

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
uninstall_companion_app
cecho "Installing companion app."
adb install -r linux-android-backup-companion.apk
cecho "Granting required permissions to companion app."
permissions=(
  'android.permission.READ_CONTACTS'
  'android.permission.WRITE_CONTACTS'
  'android.permission.READ_EXTERNAL_STORAGE'
)
# Grant permissions
for permission in "${permissions[@]}"; do
  adb shell pm grant com.example.companion_app $permission
done

if [ -d backup-tmp ]; then
  cecho "Cleaning up after previous backup/restore..."
  rm -rfv backup-tmp
fi

mkdir backup-tmp

if [ $selected_action = 'Backup' ]
then
  if [ ! -v archive_path ]; then
    echo "Note: Backups will first be made on the drive this script is located in, and then will be copied to the specified location."
    text_input "Please enter the backup location. Enter '.' for the current working directory." archive_path "."
  fi

  adb shell am start -n com.example.companion_app/.MainActivity
  cecho "The companion app has been opened on your device. Please press the 'Export Data' button - this will export contacts to the internal storage, allowing this script to backup them. Press Enter to continue."
  wait_for_enter
  uninstall_companion_app # we're uninstalling it so that it isn't included in the backup

  # Export apps (.apk files)
  cecho "Exporting apps."
  mkdir -p backup-tmp/Apps
  for app in $(adb shell pm list packages -3 -f)
  #   -f: see their associated file
  #   -3: filter to only show third party packages
  do
    declare output=backup-tmp/Apps
    (
      apk_path=${app%=*}                # apk path on device
      apk_path=${apk_path/package:}     # stip "package:"
      apk_base=$RANDOM$RANDOM$RANDOM.apk           # base apk name
      # e.g.:
      # app=package:/data/app/~~4wyPu0QoTM3AByZS==/com.whatsapp-iaTC9-W1lyR1FxO==/base.apk=com.whatsapp
      # apk_path=/data/app/~~4wyPu0QoTM3AByZS==/com.whatsapp-iaTC9-W1lyR1FxO==/base.apk
      # apk_base=896745.apk
      cd $output \
       && adb pull $apk_path $apk_base
    )
  done

  # Export contacts
  cecho "Exporting contacts (as vCard)."
  adb pull /storage/emulated/0/linux-android-backup-temp ./backup-tmp/Contacts
  cecho "Removing temporary files created by the companion app."
  adb shell rm -rf /storage/emulated/0/linux-android-backup-temp

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
  # The undefined variable is set by the user 
  7z a -p$archive_password -mhe=on -mx=9 -bb3 -sdel $archive_path/linux-android-backup-$(date +%m-%d-%Y-%H-%M-%S).7z backup-tmp/*

  cecho "Backed up successfully."
  rm -rf backup-tmp > /dev/null
elif [ $selected_action = 'Restore' ]
then
  if [ ! -v archive_path ]; then
    text_input "Please provide the location of the backup archive to restore (drag-n-drop):" archive_path
  fi

  cecho "Extracting archive."
  7z x $archive_path # -obackup-tmp isn't needed

  # Restore applications
  cecho "Restoring applications."
  # We don't want a single app to break the whole script
  set +e
  find ./backup-tmp/Apps -type f -name "*.apk" -exec adb install {} \;
  set -e

  # Restore internal storage
  cecho "Restoring internal storage."
  adb push ./backup-tmp/Storage/* /storage/emulated/0

  # Restore contacts
  cecho "Pushing backed up contacts to device."
  adb push ./backup-tmp/Contacts /storage/emulated/0/Contacts_Backup

  cecho "Data restored!"
  cecho "WARNING: Contacts have been only copied to your device. You need to open the companion app to restore them."
fi

cecho "If this project helped you, please star the GitHub repository. It lets me know that there are people using this script and I should continue working on it."
