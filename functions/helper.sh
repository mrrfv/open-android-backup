#!/bin/bash
# This file is imported by backup.sh

# Helper functions
function wait_for_enter() {
  if [ ! -v unattended_mode ]; then
    read -p "" </dev/tty
  else
    sleep 8
  fi
}

# "cecho" makes output messages yellow, if possible
function cecho() {
  if tty -s; then
    echo "$(tput setaf 11)$1$(tput init)"
  else
    echo "$1"
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

function install_companion_app() {
  cecho "Linux Android Backup will install a companion app on your device, which will allow for contacts and other data to be backed up and restored."
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
  'android.permission.READ_SMS'
  )
  # Grant permissions
  for permission in "${permissions[@]}"; do
  adb shell pm grant com.example.companion_app "$permission" || cecho "Couldn't assign permission $permission to the companion app - this is not a fatal error, and you will just have to allow this permission in the app." 1>&2
  done
}

function remove_backup_tmp() {
  # only run if backup-tmp exists
  if [ -d backup-tmp ]; then
    cecho "Cleaning up after backup/restore..."
    if [ "$data_erase_choice" = "Slow" ]; then
      cecho "Securely erasing temporary files, this will take a while."
      sleep 3
      srm -v -r -l ./backup-tmp
    elif [ "$data_erase_choice" = "Extra Slow" ]; then
      cecho "Very securely erasing temporary files, this will take a long time."
      sleep 3
      srm -v -r ./backup-tmp
    else
      cecho "Using the 'Fast' data erase mode."
      sleep 3
      rm -rfv backup-tmp
    fi
    cecho "Cleanup complete."
  else
    cecho "Couldn't find any temporary files to cleanup, continuing. This is not an error."
  fi
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
    (adb exec-out "tar -c -C $1 $2 2> /dev/null" | pv -p --timer --rate --bytes | tar -C "$3" -xf -) || cecho "Errors occurred while backing up $2 - this file (or multiple files) might've been ignored." 1>&2
  else # we're falling back to adb pull if the variable is empty/unset
    adb pull "$1"/"$2" "$3" || cecho "Errors occurred while backing up $2 - this file (or multiple files) might've been ignored." 1>&2
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