#!/bin/bash
# This file is imported by backup.sh

function backup_func() {
  while true; do
	if [ ! -v archive_path ]; then
	echo "Note: Backups will first be made on the drive this script is located in, and then will be copied to the specified location."

	# Check if we're running on Windows.
	# If we are, then we will open a file chooser instead of asking the user for the file path thru CLI
	# due to compatibility issues.
	# TODO: also do this on Linux if KDialog is available
	if [ "$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')" ];
	then
		cecho "Running on Windows (WSL) - a graphical file chooser dialog will be open."
		cecho "You will be prompted for the backup location. Press Enter to continue."
		wait_for_enter
		archive_path=$(kdialog --getexistingdirectory /mnt/c || true)
	else
		text_input "Please enter the backup location. Enter '.' for the current working directory." archive_path "."
	fi

	fi
	directory_ok "$archive_path" && break
	unset archive_path
  done

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
	  apk_base=$RANDOM$RANDOM$RANDOM$RANDOM.apk           # base apk name
	  # e.g.:
	  # app=package:/data/app/~~4wyPu0QoTM3AByZS==/com.whatsapp-iaTC9-W1lyR1FxO==/base.apk=com.whatsapp
	  # apk_path=/data/app/~~4wyPu0QoTM3AByZS==/com.whatsapp-iaTC9-W1lyR1FxO==/base.apk
	  # apk_base=47856542.apk
	  get_file "$(dirname "$apk_path")" "$(basename "$apk_path")" ./backup-tmp/Apps
	  mv "./backup-tmp/Apps/$(basename "$apk_path")" "./backup-tmp/Apps/$apk_base" || cecho "Couldn't find app $(basename "$apk_path") after exporting from device - ignoring." 1>&2
	)
  done

  # Export contacts
  cecho "Exporting contacts (as vCard)."
  mkdir ./backup-tmp/Contacts
  get_file /storage/emulated/0/linux-android-backup-temp . ./backup-tmp/Contacts
  cecho "Removing temporary files created by the companion app."
  adb shell rm -rf /storage/emulated/0/linux-android-backup-temp

  # Export internal storage. We're not using adb pull due to reliability issues
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
  sleep 2

  # Compress
  cecho "Compressing & encrypting data - this will take a while."
  # -p: encrypt backup
  # -mhe=on: encrypt headers (metadata)
  # -mx=9: ultra compression
  # -bb3: verbose logging
  # -sdel: delete files after compression
  # The undefined variable is set by the user
  declare backup_archive="$archive_path/linux-android-backup-$(date +%m-%d-%Y-%H-%M-%S).7z"
  retry 5 7z a -p"$archive_password" -mhe=on -mx=9 -bb3 -sdel "$backup_archive" backup-tmp/*

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
  rm -rf backup-tmp > /dev/null
}