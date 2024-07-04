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
  # This doesn't work on macOS so we'll skip it there
  if [[ "$(uname)" != "Darwin" ]]; then
    archive_size_kb=$(stat --printf="%s" "$archive_path" | awk '{print $1/1024}')
    if ! enough_free_space "." "$archive_size_kb"; then
      cecho "Less than $archive_size_kb KB of free space available on the current directory - not enough to extract this backup."
      cecho "Please free up some space and try again."
      exit 1
    fi
  fi

  cecho "Extracting archive."
  7z x "$archive_path" # -obackup-tmp isn't needed

  # Restore applications
  cecho "Restoring applications."
  # We don't want a single app to break the whole script
  set +e
  # Apps containing their own directories may contain split APKs, which need to be installed using adb install-multiple.
  # Those without directories were created by past versions of this script and need to be imported the traditional way.

  # Handle split APKs
  # Find directories in the Apps directory
  apk_dirs=$(find ./backup-tmp/Apps -mindepth 1 -maxdepth 1 -type d)
  for apk_dir in $apk_dirs; do
    # Install all APKs in the directory
    # the APK files are sorted to ensure that base.apk is installed before split APKs
    apk_files=$(find "$apk_dir" -type f -name "*.apk" | sort | tr '\n' ' ')
    if [[ "$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')" ]]; then
      cecho "Windows/WSL detected"
      # shellcheck disable=SC2086
      timeout 900 ./windows-dependencies/adb/adb.exe install-multiple $apk_files
    else
      cecho "macOS/Linux detected"
      if [[ "$(uname)" == "Darwin" ]]; then
        timeout_cmd="gtimeout"
      else
        timeout_cmd="timeout"
      fi
      # shellcheck disable=SC2086
      $timeout_cmd 900 adb install-multiple $apk_files
    fi
  done

  # Now all that's left is ensuring backwards compatibility with old backups
  # Look for APK files in the Apps directory
  apk_files=$(find ./backup-tmp/Apps -maxdepth 1 -type f -name "*.apk" | sort)
  # Notify if an old backup is being restored
  if [ -n "$apk_files" ]; then
    cecho "Old backup with no split APKs detected."
  fi
  # Install all APKs
  if [[ "$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')" ]]; then
    cecho "Windows/WSL detected"
    for apk_file in $apk_files; do
      timeout 900 ./windows-dependencies/adb/adb.exe install "$apk_file"
    done
  else
    cecho "macOS/Linux detected"
    if [[ "$(uname)" == "Darwin" ]]; then
      timeout_cmd="gtimeout"
    else
      timeout_cmd="timeout"
    fi

    for apk_file in $apk_files; do
      $timeout_cmd 900 adb install "$apk_file"
    done
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