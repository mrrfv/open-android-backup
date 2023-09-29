#!/usr/bin/env bash
set -e

# Application metadata - don't change
# This is used to download a stable, compatible version of the Android companion app as well as ensure backwards compatibility,
# so it should match the tag name in GitHub Releases.
# TODO: load this dynamically, i.e. configure our build system to automatically update the APP_VERSION
APP_VERSION="v1.0.14"

# We use whiptail for showing dialogs.
# Whiptail is used similarly as dialog, but we can't install it on macOS using Homebrew IIRC.
# So we need to fall back to dialog if whiptail is not available.
# Check if whiptail is installed
if command -v whiptail &> /dev/null; then
  # Whiptail is installed, no action needed. Do nothing.
  :
else
  # Check if dialog is installed
  if command -v dialog &> /dev/null; then
    echo "Whiptail is not installed, but dialog is. Defining whiptail as a function that calls dialog."
    # Define whiptail as a function that calls dialog with the same arguments
    whiptail() {
      dialog "$@"
    }
  else
    # Neither whiptail nor dialog are installed
    echo "Neither whiptail nor dialog are installed, can't continue. Please refer to the README for usage instructions."
    exit 1
  fi
fi

# Check if other dependencies are installed: adb, tar, pv, 7z
# srm is optional so we don't check for it
commands=("tar" "pv" "7z" "adb")
for cmd in "${commands[@]}"
do
  # adb is a function in WSL so we're using type instead of command -v
  if ! type "$cmd" &> /dev/null
  then
    echo "$cmd is not available, can't continue. Please refer to the README for usage instructions."
    exit 1
  fi
done


SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# ---

# Load all functions in ./functions
for f in "$DIR"/functions/*.sh; do source "$f"; done

check_adb_connection

if [ ! -v mode ]; then
  modes=( 'Wired' 'Wireless' )
  select_option_from_list "Choose the connection method. Wireless is experimental and still requires a device connected for pairing." modes[@] mode
fi

if [ "$mode" = 'Wireless' ]; then
  # See ./functions/wireless_connection.sh
  wireless_connection
fi

clear

if [ ! -v export_method ]; then
  cecho "Choose the exporting method."
  cecho "- Pick 'tar' first, as it is fast and most reliable, but might not work on all devices."
  cecho "- If the script crashes, pick 'adb' instead, which works on all devices."
  cecho "Press Enter to pick your preferred method."
  wait_for_enter

  export_methods=( 'tar' 'adb' )
  select_option_from_list "Choose the exporting method." export_methods[@] export_method
fi

clear

if [ ! -v use_hooks ]; then
  cecho "Would you like to use hooks?"
  cecho "Choose 'no' if you don't understand this question, or don't want to load hooks."
  cecho "Choose 'yes' if you have installed your own hooks and would like to use them."
  cecho "Read README.md for more information."
  cecho "USING HOOKS IS A SECURITY RISK! THEY HAVE THE EXACT SAME PERMISSIONS AS THIS SCRIPT, AND THUS CAN WIPE YOUR ENTIRE DEVICE OR SEND ALL YOUR DATA TO A REMOTE SERVER. If you are selecting 'yes', please make sure that you have read and understood the code in hooks.sh."
  cecho "Press Enter to choose."
  wait_for_enter

  should_i_use_hooks=( 'no' 'yes' )
  select_option_from_list "Use hooks? Pick No if unsure or security-conscious." should_i_use_hooks[@] use_hooks
fi

clear

if [ "$use_hooks" = "yes" ] && [ -f "./hooks.sh" ]; then
  cecho "Loading hooks - if the script crashes during this step, the error should be reported to the hook author."
  source ./hooks.sh
  sleep 4
  clear
elif [ "$use_hooks" = "yes" ]; then
  cecho "Couldn't find hooks.sh, but hooks have been enabled. Exiting."
  exit 1
fi



if command -v srm &> /dev/null
then
  if [ ! -v data_erase_choice ]; then
    cecho "Open Android Backup creates a temporary folder that contains all the data exported from your device."
    cecho "Leftovers from this folder might remain on your storage device, even after a successful backup or restore."
    cecho "The options below allow you to securely erase this data, making it harder for law enforcement and other adversaries to view your files."
    cecho "Your choice will also apply to cleanups, i.e. if the script has previously crashed without removing the files."
    cecho "Fast is considered insecure and can only be recommended on encrypted disks. Slow takes more time than the former, and it's safe enough for most people (2 passes). Extra Slow is only recommended for the paranoid (Gutmann method)."
    cecho "Press Enter to pick your data erase mode."
    wait_for_enter

    data_erase_choices=( "Fast" "Slow" "Extra Slow" )
    select_option_from_list "Choose the Data Erase Mode." data_erase_choices[@] data_erase_choice
    
    clear
  fi
else
  cecho "Couldn't find srm, a command provided by the 'secure-delete' package on Debian and Ubuntu. Secure removal of sensitive temporary files created by the script is unavailable - encrypting your disks is recommended."
  data_erase_choice="Fast"
fi

if [ ! -v selected_action ]; then
  actions=( 'Backup' 'Restore' )
  select_option_from_list "What do you want to do?" actions[@] selected_action
fi

# The companion app is required regardless of whether we're backing up the device or not,
# so we're installing it before the if statement
# See ./functions/install_companion_app.sh
install_companion_app

remove_backup_tmp

mkdir backup-tmp

if [ "$selected_action" = 'Backup' ]
then
  # See ./functions/backup_func.sh
  backup_func
elif [ "$selected_action" = 'Restore' ]
then
  # See ./functions/restore_func.sh
  restore_func
fi

if [ "$mode" = 'Wireless' ]; then
  cecho "Disconnecting from device..."
  adb disconnect
fi

cecho "If this project helped you, please star the GitHub repository. It lets me know that there are people using this script and I should continue working on it. Donations are available in my GitHub profile and will be appreciated too."
