#!/bin/bash

echo "Warning: This convenience script has been deprecated and will stop functioning in April 2024. Please use the official usage instructions instead. Read the GitHub repository's README for more information."

# Sleeping to ensure the user doesn't just ignore the warning
sleep 5

echo "Detected operating system: Linux or macOS"
echo "If you are running this script in WSL, please run it in Windows instead."
echo "Sleeping for 5 seconds to allow you to cancel..."
sleep 5

echo "Open Android Backup convenience script for Linux and macOS"
echo "This script will install dependencies, download and run the latest release of Open Android Backup."
echo "The script hasn't been fully tested, so feedback is welcome!"
echo ""

warn_untested_os() {
    echo "WARNING: This convenience script has not been tested on your operating system. It may not work as expected."
    echo "If you encounter any issues, please report them at https://github.com/mrrfv/open-android-backup/issues"
    echo "Continuing in 10 seconds..."
    sleep 10
}

# Detect OS
if [[ -n "$WSL_DISTRO_NAME" ]]; then
    echo "Please run this script from Windows. Running it directly in WSL is unsupported."
    exit 1
else
    echo "Not running in WSL, continuing..."
fi

echo "Installing dependencies - you may be prompted for your password."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if which brew >/dev/null 2>&1; then
        echo "Homebrew is installed, continuing..."
    else
        echo "Homebrew is not installed. It is needed to continue. Press Enter to automatically install Homebrew."
        read -r # wait for enter key
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install --cask android-platform-tools
    brew install p7zip pv bash dialog curl wget unzip
elif [[ -n "$(command -v apt)" ]]; then
    # Ubuntu and Debian
    sudo apt update && sudo apt install -y p7zip-full adb curl whiptail pv secure-delete wget unzip
elif [[ -n "$(command -v pacman)" ]]; then
    # Arch Linux
    warn_untested_os
    sudo pacman -Syu --noconfirm p7zip curl wget pv bash whiptail adb secure-delete unzip
elif [[ -n "$(command -v dnf)" ]]; then
    # Fedora
    warn_untested_os
    echo "You must first manually add the RPM Sphere and RPM Fusion repositories, see this link for instructions: https://rpmsphere.github.io/"
    echo "After adding the repos, press Enter to continue installing dependencies."
    read -r # wait for enter key
    sudo dnf install p7zip p7zip-plugins adb curl newt pv secure-delete
elif [[ -n "$(command -v zypper)" ]]; then
    # openSUSE
    warn_untested_os
    sudo zypper refresh && sudo zypper install -y p7zip-full curl wget pv bash whiptail android-tools secure-delete unzip
elif [[ -n "$(command -v emerge)" ]]; then
    # Gentoo Linux
    warn_untested_os
    sudo emerge --sync && sudo emerge --ask app-arch/p7zip dev-util/android-tools dev-util/curl net-misc/wget app-arch/unzip app-shells/bash app-misc/dialog app-misc/pv sys-apps/sec
elif [[ -n "$(command -v yum)" ]]; then
    # RHEL/CentOS/Oracle Linux/etc.
    warn_untested_os
    sudo yum update && sudo yum install -y p7zip curl wget pv bash whiptail android-tools secure-delete unzip

else
    echo "Unsupported operating system. Follow the regular installation instructions instead."
    echo "If you encounter any issues, please report them at https://github.com/mrrfv/open-android-backup/issues"
    exit 1
fi

echo "Downloading latest release of Open Android Backup..."
# Download latest release of Open Android Backup and run it.
OAB_DIRECTORY="open_android_backup_conveniencescript_$RANDOM"
LATEST_RELEASE=$(curl --silent "https://api.github.com/repos/mrrfv/open-android-backup/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

mkdir -pv $OAB_DIRECTORY &&
cd $OAB_DIRECTORY &&
wget "https://github.com/mrrfv/open-android-backup/releases/download/$LATEST_RELEASE/Open_Android_Backup_${LATEST_RELEASE}_Bundle.zip" &&
unzip "Open_Android_Backup_${LATEST_RELEASE}_Bundle.zip" &&
chmod +x backup.sh &&
echo "Running Open Android Backup..." &&
bash ./backup.sh ;
echo "Cleaning up..." &&
cd .. &&
rm -rf $OAB_DIRECTORY &&
echo "Done!"
