#!/usr/bin/env bash
set -e

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Load Inquirer.sh
source $DIR/inquirer-sh/list_input.sh
source $DIR/inquirer-sh/text_input.sh
# ---

# Load all functions in ./functions
for f in $DIR/functions/*; do source "$f"; done

check_adb_connection

if [ ! -v mode ]; then
  modes=( 'Wired' 'Wireless' )
  list_input "Connection method:" modes mode
fi

if [ "$mode" = 'Wireless' ]; then
  # See ./functions/wireless_connection.sh
  wireless_connection
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

cecho "If this project helped you, please star the GitHub repository. It lets me know that there are people using this script and I should continue working on it."
