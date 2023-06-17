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
  adb kill-server &> /dev/null || true
  cecho "Please enable developer options and USB debugging on your device, connect it to your computer and set it to file transfer mode. Then, press Enter to continue."
  wait_for_enter
  adb devices > /dev/null
  cecho "If you have connected your device correctly, you should now see a message asking for access to your phone. Allow it, then press Enter to go to the last step."
  cecho "Tip: If this is not the first time you're using this script, you might not need to allow anything."
  wait_for_enter
  adb devices
  cecho "Can you see your device in the list above, and does it say 'device' next to it? If not, quit this script (ctrl+c) and try again."
}

function uninstall_companion_app() {
  # Don't run this function in GitHub Actions or another CI
  if [ ! -v CI ]; then
    cecho "Attempting to uninstall companion app."
    adb uninstall com.example.companion_app &> /dev/null || true # Legacy companion app
    adb uninstall mrrfv.backup.companion &> /dev/null || true
  fi
}

function install_companion_app() {
  # Don't run this function in GitHub Actions or another CI
  if [ ! -v CI ]; then
    cecho "Open Android Backup will install a companion app on your device, which will allow for contacts and other data to be backed up and restored."
    cecho "The companion app is open-source, and you can see what it's doing under the hood on GitHub."
    if [ ! -f open-android-backup-companion.apk ]; then
      cecho "Downloading companion app."
      # -L makes curl follow redirects, -f returns an exit code different than 0 when the request fails
      if curl -L -f -o open-android-backup-companion.apk "https://github.com/mrrfv/open-android-backup/releases/download/$APP_VERSION/app-release.apk" ; then
        echo "Stable version downloaded successfully"
      else
        # A fallback to the unstable build prevents a 'race condition' where the user executes the latest version of the script while
        # GitHub hasn't finished building the companion app yet.
        cecho "Couldn't download stable version! Trying an unstable build."
        curl -L -f -o open-android-backup-companion.apk "https://github.com/mrrfv/open-android-backup/releases/download/latest/app-release.apk"
      fi
    else
      cecho "Companion app already downloaded."
    fi
    uninstall_companion_app
    cecho "Installing companion app."
    adb install -r open-android-backup-companion.apk
    cecho "Granting required permissions to companion app."
    permissions=(
    'android.permission.READ_CONTACTS'
    'android.permission.WRITE_CONTACTS'
    'android.permission.READ_EXTERNAL_STORAGE'
    'android.permission.READ_SMS'
    )
    # Grant permissions
    for permission in "${permissions[@]}"; do
      adb shell pm grant mrrfv.backup.companion "$permission" || cecho "Couldn't assign permission $permission to the companion app - this is not a fatal error, and you will just have to allow this permission in the app." 1>&2
    done
  fi
}

# A function that takes a prompt, an array of options, and a result variable as arguments
# and uses whiptail to display a menu for selecting an option
# The selected option is stored in the result variable
# If no option is selected or an error occurs, the function exits with an error message
function select_option_from_list() {
  # Assign the arguments to local variables
  local prompt="$1"
  local options=("${!2}") # Use indirect expansion to get the array from the second argument
  local result_var="$3"

  # Check if the options array is empty
  if [[ ${#options[@]} -eq 0 ]]; then
    echo "No options provided. Exiting."
    exit 1
  fi

  # Build an array of whiptail options from the options array
  local whiptail_options=()
  for ((i=0; i<${#options[@]}; i++)); do
    whiptail_options+=("$i" "${options[$i]}")
  done

  # Use whiptail to display a menu and get the selected index
  local selected_index=$(whiptail --title "Select an option" --menu "$prompt" $LINES $COLUMNS $(( $LINES - 8 )) "${whiptail_options[@]}" 3>&1 1>&2 2>&3)

  # Check if whiptail exited with a non-zero status or if no option was selected
  if [[ $? -ne 0 || -z "$selected_index" ]]; then
    echo "No option selected or whiptail error. Exiting."
    exit 1
  fi

  # Get the selected option from the options array using the selected index
  local selected_option="${options[$selected_index]}"

  # Use indirect assignment to store the selected option in the result variable
  eval $result_var="'$selected_option'"
}


function get_text_input() {
  local prompt="$1"
  local result_var="$2"
  local default_text="$3"

  while true; do
    local text_input=$(whiptail --title "$prompt" --inputbox "" $LINES $COLUMNS "$default_text" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
      echo "No text entered or whiptail error. Exiting."
      exit 1
    fi

    if [[ -z "$text_input" ]]; then
      whiptail --title "Error" --msgbox "Text cannot be empty. Please enter some text." $LINES $COLUMNS
      echo "Sleeping for 3 seconds to allow you to exit if needed..."
      sleep 3
    else
      eval $result_var="'$text_input'"
      break
    fi
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
