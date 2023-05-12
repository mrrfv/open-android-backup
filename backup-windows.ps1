Write-Output "This script lets you use open-android-backup on Windows."
Write-Output "Please ensure that you've installed the Windows Subsystem for Linux and a distro (Ubuntu or Debian) prior to running this script."
Write-Output "If not, close this window, and refer to the README for instructions (https://github.com/mrrfv/open-android-backup#windows=)"
Write-Output "If sudo asks you for your account password, don't enter your Windows password!"
Write-Output ""
Write-Output "Warning: WSL 2 is required. WSL will be updated to fix potential issues with the GUI."
Write-Output "For more information, see here: https://github.com/microsoft/wslg#install-instructions-existing-wsl-install"
Write-Output ""
pause
Write-Output "Updating WSL..."
wsl --update
wsl --shutdown
wsl sudo apt update
wsl sudo apt dist-upgrade -y
Write-Output "Installing dependencies and setting up environment..."
wsl sudo apt install p7zip-full secure-delete whiptail curl dos2unix pv kdialog '^libxcb.*-dev' libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev libxkbcommon-dev libxkbcommon-x11-dev -y
Write-Output "Converting files - this may take several minutes..."
wsl bash -c "sudo find ./ -name '*.sh' -type f -print0 | sudo xargs -0 dos2unix --"
Clear-Host
Write-Output "Ready to run the backup script."
pause
Clear-Host
wsl ./windows-dependencies/env-startup.sh
Write-Output Exiting.
pause