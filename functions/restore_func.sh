#!/bin/bash
# This file is imported by backup.sh

function restore_func() {
  if [ ! -v archive_path ]; then
    # Check if we're running on Windows.
    # If we are, then we will open a file chooser instead of asking the user for the file path thru CLI
    # due to compatibility issues.
    # TODO: also do this on Linux if KDialog is available
    if [ "$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')" ];
    then
      cecho "Running on Windows (WSL) - a graphical file chooser dialog will be open."
      cecho "You will be prompted to choose the location of the backup archive to restore. Press Enter to continue."
      wait_for_enter
      archive_path=$(kdialog --getopenfilename /mnt/c 2>/dev/null | tail -n 1 | sed 's/\r$//' || true)
      echo "$archive_path"
    else
      get_text_input "Please provide the location of the backup archive to restore (drag-n-drop):" archive_path
    fi
  fi

  if [ ! -f "$archive_path" ]; then
    cecho "The specified backup location doesn't exist or isn't a file."
    exit 1
  fi

  # Ensure there's enough space to extract the archive on the device
  # Note: this is a very rough estimate as we're not taking the compression ratio into account
  archive_size_kb=$(stat --printf="%s" "$archive_path" | awk '{print $1/1024}')
  if ! enough_free_space "." "$archive_size_kb"; then
    cecho "Less than $archive_size_kb KB of free space available on the current directory - not enough to extract this backup."
    cecho "Please free up some space and try again."
    exit 1
  fi

  cecho "Extracting archive."
  7z x "$archive_path" # -obackup-tmp isn't needed

  # Restore applications
  cecho "Restoring applications."
  # We don't want a single app to break the whole script
  set +e
  if [[ "$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')" ]]; then
    cecho "Windows/WSL detected"
    find ./backup-tmp/Apps -type f -name "*.apk" -exec ./windows-dependencies/adb/adb.exe install {} \;
  else
    cecho "macOS/Linux detected"
    find ./backup-tmp/Apps -type f -name "*.apk" -exec adb install {} \;
  fi
  set -e

  # TODO: use tar to restore data to internal storage instead of adb push

  # Restore internal storage
  cecho "Restoring internal storage."
  adb push ./backup-tmp/Storage/* /storage/emulated/0

  # Restore contacts
  cecho "Pushing backed up contacts to device."
  adb push ./backup-tmp/Contacts /storage/emulated/0/Contacts_Backup

  adb shell am start -n mrrfv.backup.companion/.MainActivity
  cecho "The companion app has been opened on your device. Please press the 'Auto-restore contacts' button - this will import your contacts to the device's contact database. Press Enter to continue."
  wait_for_enter

  # Run the third-party restore hook, if enabled.
  if [ "$use_hooks" = "yes" ] && [ "$(type -t restore_hook)" == function ]; then
    cecho "Running restore hook in 5 seconds."
    sleep 5
    restore_hook
  elif [ "$use_hooks" = "yes" ] && [ ! "$(type -t restore_hook)" == function ]; then
    cecho "WARNING! Hooks are enabled, but the restore hook hasn't been found in hooks.sh."
    cecho "Skipping in 5 seconds."
    sleep 5
  fi

  cecho "Cleaning up..."
  adb shell rm -rfv /storage/emulated/0/Contacts_Backup
  uninstall_companion_app
  remove_backup_tmp

  cecho "Data restored!"
}