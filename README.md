# Open Android Backup

<small>Formerly Linux Android Backup.</small>

Open Android Backup is a tiny shell script & Flutter app that makes securely backing up Android devices easy, without vendor lock-ins or using closed-source software that could put your data at risk. It's based on ADB but doesn't use the deprecated `adb backup` command. This project works on Windows, macOS and Linux.

![Demo](https://github.com/mrrfv/open-android-backup/raw/c86602f9e5dbc501e0eacc43fe781c352998e712/.github/images/demo.gif)

**Important:** The `master` branch is reserved for development. If you are looking for a download, please go to Releases or select a tag instead.

## Data backed up

### Restorable

The following data types can be automatically restored back to the device.

- Apps (.apk files of installed apps - app data not included - split APK support is experimental and can be found in the `split-apk-support` branch)
- Internal storage (pictures, downloads, videos, Signal backups if enabled, etc)
- Contacts (exported in vCard format)

### View-only

The following data types are only viewable by opening the backup archive with 7-Zip and cannot be restored to a device at the moment.

- SMS Messages (exported in CSV format - MMS attachments not saved)
- Call Logs (exported into a text file)

These things are the majority of what most people would want to keep safe, but everybody has different expectations and requirements, so suggestions are welcome.

## Features

- Automatically restores backed up data.
- Works on the 3 major operating systems, and supports *any* modern Android device.
- Wireless backups that allow you to normally use your phone while it's being backed up.
- Backs up data not normally accessible through ADB using a native companion app.
- Tiny - the script is 5KB in size, and the companion app is around 15 megabytes.
- Doesn't use proprietary formats - your data is safe even if you can't run the script. Simply open archives created by this script using 7-Zip.
- Backups are encrypted along with their metadata.
- Optionally securely erases all unencrypted temporary files created by the script.
- All data is compressed using 7-Zip with maximum compression settings.
## Installation

### Linux

1. Install p7zip, adb, curl, whiptail, pv, bc and optionally secure-delete. If you're on Debian or Ubuntu, run this command: `sudo apt update; sudo apt install p7zip-full adb curl whiptail pv bc secure-delete`.
On Fedora enable the RPM Sphere repo using instructions from here: https://rpmsphere.github.io/
then execute this command `sudo dnf install p7zip p7zip-plugins adb curl newt pv secure-delete`
2. [Download](https://github.com/mrrfv/open-android-backup/releases/latest) the Open Android Backup bundle, which contains the script and companion app in one package. You can also grab an experimental build (heavily discouraged) by clicking on [this link](https://github.com/mrrfv/open-android-backup/archive/refs/heads/master.zip) or cloning.
3. Enable [developer options](https://developer.android.com/studio/debug/dev-options#enable) and USB debugging on your device, then run `backup.sh` in a terminal.

### macOS

**Warning:** I've recently switched to an AMD CPU+NVIDIA GPU rig, making it impossible for me to test this script on macOS without buying a Mac. Whilst there is nothing that could prevent this script from running on macOS, you are on your own and support will be very limited. (script last tested on Janurary 11th 2023)

1. Install p7zip and adb using [Homebrew](https://brew.sh/):

```bash
# Tip: Run these commands in the built-in Terminal app (or iTerm if you have that installed).
# Install Homebrew if you haven't yet
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# If you already have Homebrew installed, just run these 2 commands:
brew install --cask android-platform-tools
brew install p7zip pv bash dialog
```

2. Follow the steps 2 and 3 from the install guide for Linux.

### Windows

1. Install the [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/install#install), a compatibility layer allowing you to run Linux applications (such as this one) on Windows. You only need to follow the `Install` step.
2. [Download](https://github.com/mrrfv/open-android-backup/releases/latest) the Open Android Backup bundle, which contains the script and companion app in one package. You can also grab an experimental build (heavily discouraged) by clicking on [this link](https://github.com/mrrfv/open-android-backup/archive/refs/heads/master.zip) or cloning.
3. Open the repository in the file explorer. Right click on a file called `backup-windows.ps1`, and click on "Run with PowerShell". **IMPORTANT: If you see an error after running the script, search for "Developer Settings" in the Settings app, and apply the settings related to PowerShell.**

![Powershell Developer Settings](.github/images/windows-powershell-developer-settings.png)
## Usage

Just run `backup.sh` and the script will walk you through the process. This section covers advanced usage of this program.

### Hooks

Open Android Backup hooks allow you to effortlessly include your own backup steps, such as those that require root or work only on specific devices, without modifying the main script. You can upload these hooks to your own GitHub repositories and share them with others.

**Info for users**

After writing or downloading a hook you'd like to use, rename it to `hooks.sh` and place in in the same directory as this script. Next, allow the use of hooks when the script asks you.

**Info for the security conscious**

Using hooks that you don't trust is a security risk that we don't claim responsibility for! They have the same access over your phone and computer as Open Android Backup, making it possible for attackers to backdoor or wipe your devices. You must check the contents of the hook you'd like to use before running the script.

Open Android Backup doesn't automatically load hooks, and you have to allow the use of them before they are even touched by the program.

**Info for developers**

*Guidelines* - follow these to futureproof your backups.

- Store the files your hook is backing up to `./backup-tmp/Hooks/<hook name>/` and make sure to create the directory before doing anything.
- In the restore hook, check if your hook's directory exists in the extracted archive (backups are always extracted to `./backup-tmp`), and don't do anything (after notifying the user) if it doesn't. This allows your hook to work with vanilla backup archives.
- In the after backup hook, you can get the backup archive path using `$backup_archive`.

*Useful functions and commands*

- `cecho <text>` lets you have yellow terminal output.
- `wait_for_enter` waits for a keypress, and is compatible with unattended mode.
- `get_file <phone_directory> <phone_file> <destination>` lets you copy files off the device with the best reliability and speed, an alternative to `adb pull`. Useful for backing up data.
- `adb push <file> <destination>` lets you upload files to the device, useful when restoring your data.

*Required functions*

You need 3 functions in your hook for it to be properly initialized by the script:

1. `after_backup_hook` - code that runs after a backup is complete, i.e. after everything gets compressed into a backup archive.
2. `backup_hook` - code that runs after the internal storage, apps, contacts and other data have been copied off the device.
3. `restore_hook` - code that runs during the restore process, allowing you to restore the data you've previously backed up.

### Automation/Unattended Backups

Please keep in mind that this project has minimal support for automation and very little support will be provided. In order to export contacts, you still need to have physical access to the device you're backing up as an "unattended mode" for the companion app hasn't been implemented yet.

There are 9 environment variables that control what the script does without user input:

1. `unattended_mode` - Instead of waiting for a key press, sleeps for 5 seconds. Can be any value.
2. `selected_action` - What the script should do when run. Possible values are `Backup` and `Restore` (case sensitive).
3. `archive_path` - Path to the backup. Works for both Restore and Backup actions.
4. `archive_password` - Backup password.
5. `mode` - How the script should connect to the device. Possible values are `Wired` and `Wireless` (case sensitive).
6. `export_method` - The method Open Android Backup should use to export data from the device. Possible values are `tar` and `adb` (case sensitive) - the former is fast & very stable but might not work on all devices, and the latter is widely compatible but has stability issues.
7. `use_hooks` - Whether to use hooks or not. Possible values are `yes` or `no` (case sensitive).
8. `data_erase_choice` - Whether to securely erase temporary files or not. Possible values are `Fast`, `Slow` and `Extra Slow` (case sensitive). The value of this variable is ignored if the command `srm` isn't present on your computer.
9. `discouraged_disable_archive` - Disables the creation of a backup archive, only creates a backup *directory* with no compression, encryption or other features. This is not recommended, although some may find it useful to deduplicate backups and save space. Restoring backups created with this option enabled is not supported by default; you must manually create an archive from the backup directory and then restore it. Possible values are `yes` or `no` (case sensitive).

Examples:

```bash
# Enable unattended mode, backup the device over the wire to the working directory and use the password "123"
$ unattended_mode="yes" selected_action="Backup" mode="Wired" export_method="tar" archive_path="." archive_password="123" ./backup.sh
# Keep unattended mode disabled, but automatically use the password "456"
$ archive_password="456" ./backup.sh
```

## Convenience Script

If you'd like to quickly run the latest version of Open Android Backup without having to follow the usage instructions, you can use the convenience script. It's a **work in progress**, but it should work on most systems.

Please note that there are **security risks** associated with running scripts from the internet. It's recommended that you review the script before running it. If you don't trust me or Cloudflare, you can always download the script and run it manually.

### Linux or macOS

Run the following command in your terminal:

```bash
curl -fsSL get.openandroidbackup.me | bash
```

### Windows

Run the following command in PowerShell:

```powershell
irm https://get.openandroidbackup.me/ | iex
```

The same path is used because the server automatically detects your operating system based on the user agent and serves the correct script.

## Building companion app

**Note:** You don't need to do this, as the precompiled companion app is automatically downloaded at runtime from GitHub Releases.

1. Install Flutter and Android Studio.
2. Run `flutter doctor` and `flutter doctor --android-licenses`.
3. Run `cd companion_app/` and `flutter build apk`.

## TODO

PRs are appreciated.

- Migrate the companion app to the Storage Access Framework API for forward compatibility (waiting for Flutter packages providing this functionality to become stable).
- Improve the error handling and design of the mobile app.
- Export the calendar and other data.

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
