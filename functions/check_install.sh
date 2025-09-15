function check_install () {
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

  # Check if other dependencies are installed: adb, tar, pv, 7z, bc, timeout
  # srm is optional so we don't check for it
  commands=("tar" "pv" "7z" "adb" "bc")


  # Add zenity to the list of commands if we're running in WSL
  if [ "$(uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip')" ]; then
    commands+=("zenity")
  fi

  # Add gtimeout to the list of commands if we're running on macOS
  if [ "$(uname)" = "Darwin" ]; then
    commands+=("gtimeout")
  else
    # For the rest of the systems, we use the standard timeout command
    commands+=("timeout")
  fi

  for cmd in "${commands[@]}"
  do
    # adb is a function in WSL so we're using type instead of command -v
    if ! type "$cmd" &> /dev/null
    then
      echo "$cmd is not available, can't continue. Please refer to the README for usage instructions."
      exit 1
    fi
  done


  # Ensure that there's enough space on the device
  # TODO: Check this based on the size of the backup (or the device's storage capacity) instead of a hardcoded value of 100GB
  if ! enough_free_space "."; then
    cecho "Less than 100GB of free space available in the current directory. You may encounter issues if working with large backups."
  fi

}
