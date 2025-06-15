Write-Output "This script lets you use open-android-backup on Windows."
Write-Output "Please ensure that you've installed the Windows Subsystem for Linux and a distro (Ubuntu or Debian) prior to running this script."
Write-Output "If not, close this window, and refer to the README for instructions (https://github.com/mrrfv/open-android-backup#windows=)"
Write-Output "If sudo asks you for your account password, don't enter your Windows password!"
Write-Output ""
Write-Output "Warning: WSL 2 is required. WSL will be updated to fix potential issues with the GUI."
Write-Output "For more information, see here: https://github.com/microsoft/wslg#install-instructions-existing-wsl-install"
Write-Output ""
pause
# Corrects the cwd if it's different than the script directory
Set-Location -Path $PSScriptRoot
# Ask the user if they want to download the latest ADB platform tools from Google
# This is done to always have the latest version and lessen the incentive to slip in malware into the repository while still respecting the user's privacy
# On Linux and macOS adb is managed by the package manager.
$downloadAdb = Read-Host "Do you want to download the latest dependencies (adb)? This will connect you to Google's servers. You can safely decline. (y/n)"
if ($downloadAdb.ToLower().StartsWith("y")) {
    # Delete ./windows-dependencies/adb/ if it exists
    if (Test-Path ./windows-dependencies/adb) {
        Remove-Item -Recurse -Force ./windows-dependencies/adb
    }
    # Download the latest adb platform tools from Google
    Write-Output "Downloading the latest ADB platform tools..."
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile "./windows-dependencies/platform-tools-latest-windows.zip"
    # Extract the downloaded zip
    Write-Output "Extracting..."
    Expand-Archive -Path "./windows-dependencies/platform-tools-latest-windows.zip" -DestinationPath "./windows-dependencies"
    # Rename the extracted folder to 'adb'
    Rename-Item -Path "./windows-dependencies/platform-tools" -NewName "./windows-dependencies/adb"
    # Remove the downloaded zip
    Remove-Item -Path "./windows-dependencies/platform-tools-latest-windows.zip"
}
# Update WSL to avoid compatibility issues
Write-Output "Updating WSL..."
wsl --update
wsl --shutdown
wsl sudo apt update
wsl sudo apt dist-upgrade -y
# Install everything we need
Write-Output "Installing dependencies and setting up environment..."
wsl sudo apt install p7zip-full secure-delete whiptail curl dos2unix pv bc zenity '^libxcb.*-dev' libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev libxkbcommon-dev libxkbcommon-x11-dev -y
# Convert line endings to Unix format, as what Windows uses by default may cause issues
Write-Output "Converting files - this may take several minutes..."
wsl bash -c "sudo find ./ -name '*.sh' -type f -print0 | sudo xargs -0 dos2unix --"
Clear-Host
Write-Output "Ready to run the backup script."
pause
Clear-Host
# Run the 'bootstrapper' script which configures the main script to use the Windows-provided adb.exe
wsl ./windows-dependencies/env-startup.sh
Write-Output Exiting.
pause
