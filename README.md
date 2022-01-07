# Linux Android Backup

Linux Android Backup is a tiny shell script & Flutter app that makes securely backing up Android devices on Linux and macOS easy, without vendor lock-ins or using closed-source software that could put your data at risk. It's based on ADB but doesn't use the deprecated `adb backup` command.

**Status:** Works, albeit testers are needed (my testbench broke).

## Data backed up

- Apps (.apk files of installed apps)
- Internal storage (pictures, downloads, videos, Signal backups if enabled, etc)
- Contacts (exported in vCard format)

These 3 things are the majority of what anyone would want to keep safe, but we all have different expectations and requirements, so suggestions are welcome.

## Features

- Automatically restores backed up data.
- Works on macOS & Linux (including WSL), and supports *any* Android device.
- Backs up data not normally accessible through ADB using a native companion app.
- Tiny - the script is 5KB in size, and the companion app is around 15 megabytes.
- Doesn't use proprietary formats: your data is safe even if this script ever gets lost. Simply open archives created by this script using 7-Zip.
- Encryption is *forced* - you can't disable it.
- All data is compressed using 7-Zip with maximum compression settings.

## Installation

### Linux

1. Install p7zip, adb and curl (if you're on Debian or Ubuntu, run this command: `sudo apt update; sudo apt install p7zip-full adb curl`).
2. Clone or [download](https://github.com/mrrfv/linux-android-backup/archive/refs/heads/master.zip) this repository.
3. Enable [developer options](https://www.androidauthority.com/enable-developer-options-569223/) and USB debugging on your device and run `backup.sh` in a terminal.

### macOS

1. Install p7zip, adb and curl using [Homebrew](https://brew.sh/):

```bash
# Tip: Run these commands in the built-in Terminal app (or iTerm if you have that installed).
# Install Homebrew if you haven't yet
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# If you already have Homebrew installed, just run these 3 commands:
brew install --cask android-platform-tools
brew install p7zip
brew install curl
```

2. Follow the steps 2 and 3 from the install guide for Linux.

### Windows

1. Install the [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/install#install), a compatibility layer allowing you to run Linux applications (such as this one) on Windows. You only need to follow the `Install` step.
2. Open an app called "Ubuntu" or "Debian". It should be in your start menu.
3. Navigate to your desktop by running `cd Desktop`. *(optional)*
4. Follow all steps from the install guide for Linux.

## Building companion app

**Note:** You don't need to do this, as the precompiled companion app is automatically downloaded at runtime from GitHub Releases.

1. Install Flutter and Android Studio.
2. Run `flutter doctor` and `flutter doctor --android-licenses`.
3. Run `cd companion_app/` and `flutter build apk`.

## TODO

Sorted by importance. PRs are appreciated.

- Write usage instructions
- Create a desktop GUI for newcomers (using Flutter maybe?)
- Improve mobile app by fixing bugs and making it more appealing
- Clean up the code
- Migrate companion app to the Storage Access Framework API for forward compatibility (waiting for Flutter packages providing this functionality to become stable).

## License

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
