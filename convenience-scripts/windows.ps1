echo "Detected operating system: Windows"
echo "Sleeping for 5 seconds to allow you to cancel..."
sleep 5

Write-Output "Open Android Backup - Windows Convenience Script"
Write-Output "This script lets you use open-android-backup on Windows."
Write-Output "Please remember that this script hasn't been fully tested, and may contain bugs."

$distros = Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss" |
    ForEach-Object { Get-ItemProperty $_.PsPath } |
    Select-Object DistributionName, Version

if ($distros.Count -eq 0) {
    Write-Output "No WSL distros found. Please install a distro using 'wsl --install' and try again."
    exit
}

$ubuntu = $distros | Where-Object { $_.DistributionName -eq "Ubuntu" }
$debian = $distros | Where-Object { $_.DistributionName -eq "Debian" }

if ($null -ne $ubuntu) {
    if ($ubuntu.Version -eq 2) {
        Write-Output "Ubuntu is installed and running WSL 2. Using Ubuntu."
        $distro = "Ubuntu"
    } else {
        Write-Output "Ubuntu is installed but running WSL 1. Please convert it to WSL 2."
        exit
    }
} elseif ($null -ne $debian) {
    if ($debian.Version -eq 2) {
        Write-Output "Debian is installed and running WSL 2. Using Debian."
        $distro = "Debian"
    } else {
        Write-Output "Debian is installed but running WSL 1. Please convert it to WSL 2."
        exit
    }
} else {
    Write-Output "Neither Ubuntu nor Debian is installed. Please install one of these WSL distros and try again."
    exit
}

pause
Write-Output "Updating WSL..."
wsl --update
wsl --shutdown
wsl -d $distro sudo apt update
wsl -d $distro sudo apt dist-upgrade -y
Write-Output "Installing dependencies and setting up environment..."
wsl -d $distro sudo apt install p7zip-full secure-delete whiptail curl dos2unix pv kdialog '^libxcb.*-dev' libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev libxkbcommon-dev libxkbcommon-x11-dev -y
Write-Output "Downloading latest release of Open Android Backup..."

$RANDOM = Get-Random -Minimum 1000 -Maximum 1000000
$OAB_DIRECTORY="open_android_backup_conveniencescript_$($RANDOM)"
$LATEST_RELEASE=(Invoke-WebRequest -Uri "https://api.github.com/repos/mrrfv/open-android-backup/releases/latest" -UseBasicParsing | ConvertFrom-Json).tag_name

New-Item -ItemType Directory -Path $OAB_DIRECTORY -Force | Out-Null
Set-Location $OAB_DIRECTORY
Invoke-WebRequest -Uri "https://github.com/mrrfv/open-android-backup/releases/download/$LATEST_RELEASE/Open_Android_Backup_${LATEST_RELEASE}_Bundle.zip" -OutFile "Open_Android_Backup_${LATEST_RELEASE}_Bundle.zip"
Expand-Archive "Open_Android_Backup_${LATEST_RELEASE}_Bundle.zip" -DestinationPath .
Write-Output "Converting files - this may take several minutes..."
wsl -d $distro bash -c "sudo find ./ -name '*.sh' -type f -print0 | sudo xargs -0 dos2unix --"
Write-Output "Running Open Android Backup..."
wsl -d $distro ./windows-dependencies/env-startup.sh
Write-Output "Cleaning up..."
wsl --shutdown
try {
    Stop-Process -Name adb.exe -Force | Out-Null
    Stop-Process -Name adb -Force | Out-Null
} catch {
    Write-Output "adb not running."
}
Set-Location ..
Remove-Item $OAB_DIRECTORY -Recurse -Force
Write-Output "Done!"
Write-Output "Exiting."
pause