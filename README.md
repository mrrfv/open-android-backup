# Linux Android Backup

Linux Android Backup is a tiny shell script & Flutter app that makes securely backing up Android devices on Linux and macOS easy, without vendor lock-ins or using closed-source software that could put your data at risk. It's based on ADB but doesn't use the deprecated `adb backup` command.

**Status:** Works, but not yet ready for production use - Edge cases are not yet handled properly, and the companion app is buggy.

## Data backed up

- App list (apps are semi-automatically restored by programmatically opening the Google Play Store; TODO save the .apk files themselves)
- Internal storage (pictures, downloads, videos, Signal backups if enabled, etc)
- Contacts (exported in vCard format)

These 3 things are the majority of what anyone would want to keep safe, but we all have different expectations and requirements, so suggestions are welcome.

## Features

- Works on macOS & Linux (including WSL), and supports *any* Android device.
- Encryption is *forced* - you can't disable it.
- All data is compressed using 7-Zip with maximum compression settings.
- Tiny - the script is 5KB in size, and the companion app is around 15 megabytes.
- Doesn't use proprietary formats: your data is safe even if this script ever gets lost. Simply open archives created by this script using 7-Zip.
- A companion app that exports data not normally accessible through ADB, such as contacts, written in Dart (Flutter).

## Installation

1. Install p7zip (`p7zip-full` on Ubuntu) and adb.
2. Clone this repository.
3. Enable developer options on your device and run `backup.sh`.

## License

This software is licensed under the "Linux Android Backup License", a license based on the BSD 3-Clause license, but with another clause preventing the use of this software by law enforcement.

## TODO

Sorted by importance.

- Automatically import contacts.
- Export .apk files of installed apps and automatically restore them.
- Clean up the code & add proper error handling
