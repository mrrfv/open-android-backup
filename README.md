# Linux Android Backup

Linux Android Backup is a tiny shell script & Flutter app that makes securely backing up Android devices on Linux and macOS easy, without vendor lock-ins or using closed-source software that could put your data at risk. It's based on ADB but doesn't use the deprecated `adb backup` command.

**Status:** Works, but not yet ready for production use - Edge cases are not handled properly, and the companion app is buggy.

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

1. Install p7zip and adb (`sudo apt update; sudo apt install p7zip-full adb` on Debian).
2. Clone or download this repository.
3. Enable developer options on your device and run `backup.sh`.

## Running under Windows

1. Install the [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install) and a distro (Debian or Ubuntu is recommended).
2. Continue with the steps above.

## License

This software is licensed under the "Linux Android Backup License", a license based on the BSD 3-Clause license, but with another clause preventing the use of this software by law enforcement.

## TODO

Sorted by importance. PRs are appreciated.

- Create a desktop GUI for newcomers (using Flutter maybe?)
- Improve mobile app by fixing bugs and making it more appealing
- Clean up the code
