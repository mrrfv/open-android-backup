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
    sleep 5s
  fi
}

# "cecho" makes output messages yellow, if possible
function cecho() {
  if [ ! -v CI ]; then
    echo $(tput setaf 11)$1
  else
    echo $1
  fi
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

function retry() {
    local -r -i max_attempts="$1"; shift
    local -i attempt_num=1
    until "$@"
    do
        if ((attempt_num==max_attempts))
        then
            echo "Attempt $attempt_num failed and there are no more attempts left!"
            return 1
        else
            echo "Attempt $attempt_num failed! Trying again in $attempt_num seconds..."
            sleep $((attempt_num++))
        fi
    done
}

# Usage: get_file <directory> <file> <destination>
function get_file() {
  if [ "$export_method" = 'tar' ]; then
    adb exec-out "tar -c -C $1 $2 2> /dev/null" | pv -p --timer --rate --bytes | tar -C $3 -xf -
  else # we're falling back to adb pull if the variable is empty/unset
    adb pull $1/$2 $3
  fi
}

# Usage: directory_ok <directory>
# Returns 0 (true) or 1 (false)
function directory_ok() {
    if [ ! -d "$1" ]; then
      cecho "Can't find directory '$1'"
      echo "Please re-enter the path, or hit ^C to exit"
      return 1
    fi
    if [ ! -w "$1" ]; then
      cecho "No write permission for directory '$1'"
      echo "Please enter  a new path, or hit ^C to exit"
      return 1
    fi
    return 0
}
# ---


check_adb_connection

if [ ! -v mode ]; then
  modes=( 'Wired' 'Wireless' )
  list_input "Connection method:" modes mode
fi

if [ "$mode" = 'Wireless' ]; then
  cecho "Warnings:"
  cecho "1. Wireless backups are experimental and might not work on all devices."
  cecho "2. Your computer and phone need to be connected to the same WiFi network."
  cecho "3. Keep your phone connected to the PC until the connection is established."
  cecho "Press Enter to continue."
  wait_for_enter

  cecho "Establishing connection..."
  adb tcpip 5353
  sleep 5
  adb connect $(adb shell ip addr show wlan0 | grep 'inet ' | cut -d ' ' -f 6 | cut -d / -f 1):5353

  cecho "Please unplug your device from the computer, and press Enter to continue."
  wait_for_enter
  adb devices
  cecho "If you can see an IP address in the list above, and it says 'device' next to it, then you have successfully established a connection to the phone."
  cecho "If it says 'unauthorized' or similar, then you need to unlock your device and approve the connection before continuing."
fi

if [ ! -v export_method ]; then
  cecho "Choose the exporting method."
  cecho "- Pick 'tar' first, as it is fast and most reliable, but might not work on all devices."
  cecho "- If the script crashes, pick 'adb' instead, which works on all devices."

  export_methods=( 'tar' 'adb' )
  list_input "Exporting method:" export_methods export_method
fi

if [ ! -v use_hooks ]; then
  cecho "Would you like to use hooks?"
  cecho "Choose 'no' if you don't understand this question, or don't want to load hooks."
  cecho "Choose 'yes' if you have installed your own hooks and would like to use them."
  cecho "Read README.md for more information."
  cecho "USING HOOKS IS A SECURITY RISK! THEY HAVE THE EXACT SAME PERMISSIONS AS THIS SCRIPT, AND THUS CAN WIPE YOUR ENTIRE DEVICE OR SEND ALL YOUR DATA TO A REMOTE SERVER. If you are selecting 'yes', please make sure that you have read and understood the code in hooks.sh."

  should_i_use_hooks=( 'no' 'yes' )
  list_input "Use hooks:" should_i_use_hooks use_hooks
fi

if [ "$use_hooks" = "yes" ] && [ -f "./hooks.sh" ]; then
  cecho "Loading hooks - if the script crashes during this step, the error should be reported to the hook author."
  source ./hooks.sh
elif [ "$use_hooks" = "yes" ]; then
  cecho "Couldn't find hooks.sh, but hooks have been enabled. Exiting."
  exit 1
fi


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

# Only make tmp directory if we are going to compress files
if [ "$compression_level" != "0" ]; then
  mkdir backup-tmp
fi

if [ $selected_action = 'Backup' ]
then
  # Set whether or not to use compression and set the level
  text_input "Enter compression level (Set to 0 to disable compression and copy files directly to staorage location):" compression_level 0

  while true; do
    if [ ! -v archive_path ]; then
      if [ "$compression_level" != "0" ]; then
        echo "Note: Backups will first be made on the drive this script is located in, and then will be compressed to the specified location."
      else
        echo "Files will be copied to this directory directly without oompression."
      fi
      text_input "Please enter the backup location. Enter '.' for the current working directory." archive_path "."
    fi
    directory_ok "$archive_path" && break
    unset archive_path
  done

  if  [ "$compression_level" = "0" ]; then
    backup_path=$archive_path
    ## Check to see if directory has "Apps" and ask if we want to delete
    if [ -d "$archive_path/Apps" ]; then
      actions=( 'Yes' 'No' )
      list_input "Directory $archive_path appears to contain a backup. Delete files?" actions selected_action
      if [ "$selected_action" = "Yes" ]; then
        rm -rf $archive_path/* > /dev/null
      fi
    fi
  else
    backup_path="backup-tmp"
  fi

  cecho "Exporting to $backup_path"

  adb shell am start -n com.example.companion_app/.MainActivity
  cecho "The companion app has been opened on your device. Please press the 'Export Data' button - this will export contacts to the internal storage, allowing this script to backup them. Press Enter to continue."
  wait_for_enter
  uninstall_companion_app # we're uninstalling it so that it isn't included in the backup

  # Export apps (.apk files)
  cecho "Exporting apps."
  mkdir -p $backup_path/Apps | true # | true to avoid script aborting due to directory exists
  for app in $(adb shell pm list packages -3 -f)
  #   -f: see their associated file
  #   -3: filter to only show third party packages
  do
    declare output=$backup_path/Apps
    (
      apk_path=${app%=*}                # apk path on device
      apk_path=${apk_path/package:}     # stip "package:"
      apk_base=$RANDOM$RANDOM$RANDOM$RANDOM.apk           # base apk name
      # e.g.:
      # app=package:/data/app/~~4wyPu0QoTM3AByZS==/com.whatsapp-iaTC9-W1lyR1FxO==/base.apk=com.whatsapp
      # apk_path=/data/app/~~4wyPu0QoTM3AByZS==/com.whatsapp-iaTC9-W1lyR1FxO==/base.apk
      # apk_base=47856542.apk
      get_file $(dirname $apk_path) $(basename $apk_path) $backup_path/Apps
      mv $backup_path/Apps/$(basename $apk_path) $backup_path/Apps/$apk_base
    )
  done

  # Export contacts
  cecho "Exporting contacts (as vCard)."
  mkdir $backup_path/Contacts | true
  get_file /storage/emulated/0/linux-android-backup-temp . $backup_path/Contacts
  cecho "Removing temporary files created by the companion app."
  adb shell rm -rf /storage/emulated/0/linux-android-backup-temp

  # Export internal storage. We're not using adb pull due to reliability issues
  cecho "Exporting internal storage - this will take a while."
  mkdir $backup_path/Storage | true
  get_file /storage/emulated/0 . $backup_path/Storage

  # Run the third-party backup hook, if enabled.
  if [ "$use_hooks" = "yes" ] && [ $(type -t backup_hook) == function ]; then
    cecho "Running backup hooks in 5 seconds."
    sleep 5
    backup_hook
  elif [ "$use_hooks" = "yes" ] && [ ! $(type -t backup_hook) == function ]; then
    cecho "WARNING! Hooks are enabled, but the backup hook hasn't been found in hooks.sh."
    cecho "Skipping in 5 seconds."
    sleep 5
  fi

  # All data has been collected and the phone can now be unplugged
  cecho "---"
  cecho "All required data has been copied from your device and it can now be unplugged."
  cecho "---"
  sleep 2

  # Compress
  if [ "$compression_level" != 0 ]; then
    cecho "Compressing & encrypting data - this will take a while."
    # -p: encrypt backup
    # -mhe=on: encrypt headers (metadata)
    # -mx=9: ultra compression
    # -bb3: verbose logging
    # -sdel: delete files after compression
    # The undefined variable is set by the user
    declare backup_archive="$archive_path/linux-android-backup-$(date +%m-%d-%Y-%H-%M-%S).7z"
    retry 5 7z a -p$archive_password -mhe=on -mx=9 -bb3 -sdel $backup_archive backup-tmp/*
  fi

  if [ "$use_hooks" = "yes" ] && [ $(type -t after_backup_hook) == function ]; then
    cecho "Running after backup hook in 5 seconds."
    sleep 5
    after_backup_hook
  elif [ "$use_hooks" = "yes" ] && [ ! $(type -t after_backup_hook) == function ]; then
    cecho "WARNING! Hooks are enabled, but an after backup hook hasn't been found in hooks.sh."
    cecho "Skipping in 5 seconds."
    sleep 5
  fi

  cecho "Backed up successfully."
  rm -rf backup-tmp > /dev/null
elif [ $selected_action = 'Restore' ]
then
  if [ ! -v archive_path ]; then
    text_input "Please provide the location of the backup directory/archive to restore (drag-n-drop):" archive_path
  fi

  if [ ! -f "$archive_path" -a "${archive_path##*.}" = "7z" ]; then
      cecho "The specified backup location doesn't exist or isn't a file."
      exit 1
  # If we're restoring from uncompressed backup, make sure at lease the Apps directory exists
  elif [ ! -d "$archive_path/Apps" -a "${archive_path##*.}" != "7z" ]; then 
      cecho "The specified backup directory does not exist."
      exit 1
  fi

  if [ "${archive_path##*.}" = "7z" ]; then
    cecho "Extracting archive."
    7z x $archive_path # -obackup-tmp isn't needed
  fi

  # Restore applications
  cecho "Restoring applications."
  # We don't want a single app to break the whole script
  set +e
  if [[ $(grep microsoft /proc/version) ]]; then
    cecho "Windows/WSL detected"
    find $archive_path/Apps -type f -name "*.apk" -exec ./windows-dependencies/adb.exe install {} \;
  else
    cecho "macOS/Linux detected"
    find $archive_path/Apps -type f -name "*.apk" -exec adb install {} \;
  fi
  set -e

  # TODO: use tar to restore data to internal storage instead of adb push

  # Restore internal storage
  cecho "Restoring internal storage."
  adb push $archive_path/Storage/* /storage/emulated/0

  # Restore contacts
  cecho "Pushing backed up contacts to device."
  adb push $archive_path/Contacts /storage/emulated/0/Contacts_Backup

  adb shell am start -n com.example.companion_app/.MainActivity
  cecho "The companion app has been opened on your device. Please press the 'Auto-restore contacts' button - this will import your contacts to the device's contact database. Press Enter to continue."
  wait_for_enter

  # Run the third-party restore hook, if enabled.
  if [ "$use_hooks" = "yes" ] && [ $(type -t restore_hook) == function ]; then
    cecho "Running restore hook in 5 seconds."
    sleep 5
    restore_hook
  elif [ "$use_hooks" = "yes" ] && [ ! $(type -t restore_hook) == function ]; then
    cecho "WARNING! Hooks are enabled, but the restore hook hasn't been found in hooks.sh."
    cecho "Skipping in 5 seconds."
    sleep 5
  fi

  cecho "Cleaning up..."
  adb shell rm -rfv /storage/emulated/0/Contacts_Backup

  cecho "Data restored!"
fi

if [ "$mode" = 'Wireless' ]; then
  cecho "Disconnecting from device..."
  adb disconnect
fi

cecho "If this project helped you, please star the GitHub repository. It lets me know that there are people using this script and I should continue working on it."
