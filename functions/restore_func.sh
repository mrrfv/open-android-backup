#!/bin/bash
# This file is imported by backup.sh

function restore_func() {
  if [ ! -v archive_path ]; then
  # Ask the user for the backup location
  # If zenity is available, we'll use it to show a graphical file chooser
  # TODO: Extract this into a function since similar code is used when backing up
  if command -v zenity >/dev/null 2>&1 && { [ "$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')" ] || [ -z "$XDG_DATA_DIRS" ]; } ;
  then
    cecho "A graphical file chooser dialog will be open."
    cecho "You will be prompted for the location of the backup archive to restore. Press Enter to continue."
    wait_for_enter

    # Dynamically set the default directory based on the operating system
    zenity_backup_default_dir="$HOME"
    if [ "$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')" ]; then
      zenity_backup_default_dir="/mnt/c/Users"
    fi

    archive_path=$(zenity --file-selection --title="Choose the backup location" --filename="$zenity_backup_default_dir" 2>/dev/null | tail -n 1 | sed 's/\r$//' || true)
  else
    # Fall back to the CLI if zenity isn't available (e.g. on macOS)
    get_text_input "Please provide the location of the backup archive to restore (drag-n-drop, remove quotation marks):" archive_path ""
    cecho "Install zenity to use a graphical file chooser."
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
  # There's a 15 minute timeout for app installs just in case there is a
  # misbehaving app blocking the whole restore process.
  # Please note that this doesn't forcibly kill adb, rather it sends a simple SIGTERM signal.
  if [[ "$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')" ]]; then
    cecho "Windows/WSL detected"
    find ./backup-tmp/Apps -type f -name "*.apk" -exec timeout 900 ./windows-dependencies/adb/adb.exe install {} \;
  else
    cecho "macOS/Linux detected"
    find ./backup-tmp/Apps -type f -name "*.apk" -exec timeout 900 adb install {} \;
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