#!/bin/bash
# This file is imported by backup.sh

function backup_func() {
  while true; do
  if [ ! -v archive_path ]; then
  # Check if we're running on Windows.
  # If we are, then we will open a file chooser instead of asking the user for the file path thru CLI
  # due to compatibility issues.
  # TODO: also do this on Linux if KDialog is available
  if [ "$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')" ];
  then
    cecho "Running on Windows (WSL) - a graphical file chooser dialog will be open."
    cecho "You will be prompted for the backup location. Press Enter to continue."
    wait_for_enter
    archive_path=$(kdialog --getexistingdirectory /mnt/c 2>/dev/null | tail -n 1 | sed 's/\r$//' || true)
  else
    get_text_input "Enter the backup location. Press Ok for the current working directory." archive_path "$(pwd)"
  fi

  fi
  directory_ok "$archive_path" && break
  unset archive_path
  done

  adb shell am start -n mrrfv.backup.companion/.MainActivity
  cecho "The companion app has been opened on your device. Please press the 'Export Data' button - this will export contacts/messages to internal storage, allowing this script to back them up. When this is complete, press Enter to continue."
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
    apk_path=${app%=*}                                  # apk path on device
    apk_path=${apk_path/package:}                       # strip "package:"
    apk_clean_name=$(echo "$app" | awk -F "=" '{print $NF}' | tr -dc '[:alnum:].' | tr '[:upper:]' '[:lower:]') # package name
    apk_base="$apk_clean_name-$RANDOM$RANDOM.apk"  # apk filename in the backup archive
    # e.g.:
    # app=package:/data/app/~~4wyPu0QoTM3AByZS==/org.fdroid.fdroid-iaTC9-W1lyR1FxO==/base.apk=org.fdroid.fdroid
    # apk_path=/data/app/~~4wyPu0QoTM3AByZS==/org.fdroid.fdroid-iaTC9-W1lyR1FxO==/base.apk
    # apk_clean_name=org.fdroid.fdroid
    # apk_base=org.fdroid.fdroid-123456.apk
    
    echo "Backing up app: $apk_clean_name"

    get_file "$(dirname "$apk_path")" "$(basename "$apk_path")" ./backup-tmp/Apps
    mv "./backup-tmp/Apps/$(basename "$apk_path")" "./backup-tmp/Apps/$apk_base" || cecho "Couldn't find app $(basename "$apk_path") after exporting from device - ignoring." 1>&2
  )
  done

  # Export contacts and SMS messages
  cecho "Exporting contacts (as vCard), call logs as well as SMS messages (as CSV)."
  # Get the entire oab-temp directory
  mkdir ./backup-tmp/open-android-backup-temp
  if ! get_file /storage/emulated/0/open-android-backup-temp . ./backup-tmp/open-android-backup-temp; then
    cecho "Error: Failed to get data from the Companion App! Please make sure that you have pressed the 'Export Data' button in the Companion App."
    cecho "If you have already done that, please report this issue on GitHub."
    cecho "Cannot continue - exiting."
    exit 1
  fi
  # Get contacts
  mkdir ./backup-tmp/Contacts
  mv ./backup-tmp/open-android-backup-temp/open-android-backup-contact*.vcf ./backup-tmp/Contacts || cecho "No contacts found on device - ignoring." 1>&2
  # Get SMS messages
  mkdir ./backup-tmp/SMS
  mv ./backup-tmp/open-android-backup-temp/SMS_Messages.csv ./backup-tmp/SMS
  # Get call logs
  mkdir ./backup-tmp/CallLogs
  mv ./backup-tmp/open-android-backup-temp/Call_Logs.csv ./backup-tmp/CallLogs
  # Cleanup
  cecho "Removing temporary files created by the companion app."
  adb shell rm -rf /storage/emulated/0/open-android-backup-temp
  rm -rf ./backup-tmp/open-android-backup-temp

  # Export internal storage
  cecho "Exporting internal storage - this will take a while."
  mkdir ./backup-tmp/Storage
  get_file /storage/emulated/0 . ./backup-tmp/Storage

  # Run the third-party backup hook, if enabled.
  if [ "$use_hooks" = "yes" ] && [ "$(type -t backup_hook)" == "function" ]; then
    cecho "Running backup hooks in 5 seconds."
    sleep 5
    backup_hook
  elif [ "$use_hooks" = "yes" ] && [ ! "$(type -t backup_hook)" == "function" ]; then
    cecho "WARNING! Hooks are enabled, but the backup hook hasn't been found in hooks.sh."
    cecho "Skipping in 5 seconds."
    sleep 5
  fi

  # All data has been collected and the phone can now be unplugged
  cecho "---"
  cecho "All required data has been copied from your device and it can now be unplugged."
  cecho "---"
  sleep 4

  # Copy backup_archive_info.txt to the archive
  cp "$DIR/extras/backup_archive_info.txt" ./backup-tmp/PLEASE_READ.txt
  echo "$APP_VERSION" > ./backup-tmp/version.txt

  # If the "discouraged_disable_archive" is set to "yes", then we'll only create a directory with the backup files.
  if [ "$discouraged_disable_archive" = "yes" ]; then
    cecho "Skipping compression & encryption due to the 'discouraged_disable_archive' option being set to 'yes'."
    cecho "The backup data will be stored in a directory instead."
    # TODO: clean up the code, i.e. remove the repetition
    declare backup_archive="$archive_path/open-android-backup-$(date +%m-%d-%Y-%H-%M-%S)"
    mkdir -p "$archive_path/open-android-backup-$(date +%m-%d-%Y-%H-%M-%S)"
    mv ./backup-tmp "$archive_path/open-android-backup-$(date +%m-%d-%Y-%H-%M-%S)"
  else
    # Compress
    cecho "Compressing & encrypting data - this will take a while."
    # 7-Zip options:
    # -p: encrypt backup
    # -mhe=on: encrypt headers (metadata)
    # -mx=9: ultra compression
    # -bb3: verbose logging
    # The undefined variable (archive_password) is set by the user if they're using unattended mode
    declare backup_archive="$archive_path/open-android-backup-$(date +%m-%d-%Y-%H-%M-%S).7z"
    retry 5 7z a -p"$archive_password" -mhe=on -mx=7 -bb3 "$backup_archive" backup-tmp/*
  fi

  # We're not using 7-Zip's -sdel option (delete files after compression) to honor the user's choice to securely delete temporary files after a backup
  remove_backup_tmp  

  if [ "$use_hooks" = "yes" ] && [ "$(type -t after_backup_hook)" == function ]; then
    cecho "Running after backup hook in 5 seconds."
    sleep 5
    after_backup_hook
  elif [ "$use_hooks" = "yes" ] && [ ! "$(type -t after_backup_hook)" == function ]; then
    cecho "WARNING! Hooks are enabled, but an after backup hook hasn't been found in hooks.sh."
    cecho "Skipping in 5 seconds."
    sleep 5
  fi

  cecho "Backed up successfully."
  cecho "Note: SMS messages and call logs cannot be restored by Open Android Backup at the moment. They are included in the backup archive for your own purposes."
  cecho "You can find them by opening the backup archive using 7-Zip."
}
