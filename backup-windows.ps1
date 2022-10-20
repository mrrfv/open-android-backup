Write-Output "This script lets you use linux-android-backup on Windows."
Write-Output "Please ensure that you've installed the Windows Subsystem for Linux and a distro (Ubuntu or Debian) prior to running this script."
Write-Output "If not, close this window, and refer to the README for instructions (https://github.com/mrrfv/linux-android-backup#windows=)"
Write-Output .
pause
Write-Output "Installing dependencies and setting up environment..."
wsl sudo apt update
wsl sudo apt install p7zip-full curl bc dos2unix pv -y
wsl bash -c "sudo find ./ -type f -print0 | sudo xargs -0 dos2unix --"
Clear-Host
Write-Output "Ready to run the backup script."
pause
Clear-Host
wsl ./windows-dependencies/env-startup.sh
Write-Output Exiting.
pause