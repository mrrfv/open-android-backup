import 'package:flutter/material.dart';
import 'dart:io';

import './services/backup_service.dart';
import './widgets/progress_widgets.dart';
import 'services/file_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final BackupService _backupService = BackupService();

  // for backups
  bool showBackupProgress = false;
  int contactsAmountDatabase = 0;
  int contactsExported = 0;
  int smsMessageCount = 0;
  int smsMessagesExported = 0;
  int callLogsAmount = -1; // -1 => not loaded yet, 0 => no call logs found
  int callLogsExported = 0;
  // for restores
  bool showRestoreProgress = false;
  int contactsAmountFilesystem = 0;
  int contactsImported = 0;

  final FileService fileService = FileService();

  // No directory paths needed for main screen - uses hardcoded directories

  @override
  void initState() {
    super.initState();

    // Set up progress callbacks
    _backupService.onContactsProgress = (current, total) {
      setState(() {
        contactsExported = current;
        contactsAmountDatabase = total;
      });
    };

    _backupService.onSmsProgress = (current, total) {
      setState(() {
        smsMessagesExported = current;
        smsMessageCount = total;
      });
    };

    _backupService.onCallLogsProgress = (current, total) {
      setState(() {
        callLogsExported = current;
        callLogsAmount = total;
      });
    };

    _backupService.onImportProgress = (current, total) {
      setState(() {
        contactsImported = current;
        contactsAmountFilesystem = total;
      });
    };
  }

  Future<void> backup(BuildContext context) async {
    // Use hardcoded temp directory for main screen
    const exportDir = "/storage/emulated/0/open-android-backup-temp";

    setState(() {
      showBackupProgress = true;
      contactsExported = 0;
      smsMessagesExported = 0;
      callLogsExported = 0;
      contactsAmountDatabase = 0;
      smsMessageCount = 0;
      callLogsAmount = -1;
    });

    try {
      // First check permissions
      if (!(await fileService.checkStoragePermissions())) {
        throw Error();
      }

      // Recreate the temp directory if it already exists
      final directory = Directory(exportDir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await directory.create();

      // Use BackupService to export data to temp directory
      final success = await _backupService.exportContacts(exportDir);
      if (!success) {
        showInfoDialog(context, "Export Failed", "Failed to export contacts.");
        return;
      }

      final smsSuccess = await _backupService.exportSms(exportDir);
      if (!smsSuccess) {
        showInfoDialog(context, "Export Failed", "Failed to export SMS messages.");
        return;
      }

      final callLogsSuccess = await _backupService.exportCallLogs(exportDir);
      if (!callLogsSuccess) {
        showInfoDialog(context, "Export Failed", "Failed to export call logs.");
        return;
      }

      showInfoDialog(context, "Data Exported",
          "Data has been exported to the temp directory. Please continue the backup process on your computer.");
    } catch (e) {
      showInfoDialog(context, "Error", "Export failed: ${e.toString()}");
    } finally {
      setState(() {
        showBackupProgress = false;
      });
    }
  }

  Future<void> autoRestoreContacts(BuildContext context) async {
    // Use hardcoded Contacts_Backup directory for main screen imports
    const importDir = "/storage/emulated/0/Contacts_Backup";

    setState(() {
      showRestoreProgress = true;
      contactsImported = 0;
      contactsAmountFilesystem = 0;
    });

    try {
      // Check if the Contacts_Backup directory exists
      final contactsDir = Directory(importDir);
      if (!await contactsDir.exists()) {
        showInfoDialog(context, "Error",
            "The contact backup directory couldn't be found.");
        return;
      }

      // Use BackupService to import contacts from hardcoded directory
      final success = await _backupService.importContacts(importDir);

      if (success) {
        showInfoDialog(context, "Success", "Data has been imported.");
      } else {
        showInfoDialog(context, "Error", "No contacts were imported.");
      }
    } catch (e) {
      showInfoDialog(context, "Error", "Import failed: ${e.toString()}");
    } finally {
      setState(() {
        showRestoreProgress = false;
      });
    }
  }

  void showInfoDialog(BuildContext context, String title, String description) {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, 'Close'),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Text(
            "This app works best with the Open Android Backup script running on your computer. However, you can still use the advanced mode for standalone exports and imports."),
        const Divider(
          color: Color.fromARGB(31, 44, 44, 44),
          height: 25,
          thickness: 1,
          indent: 5,
          endIndent: 5,
        ),
        // data export section
        Row(
          children: const [
            Icon(Icons.file_upload, size: 24, color: Colors.green),
            SizedBox(width: 8),
            Text(
              "Export Data",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Text(
          "Press the button below to export your contacts, SMS messages and call logs. After the export is complete, please continue the backup process on your computer.",
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              showBackupProgress = true;
            });
            backup(context);
          },
          child: const Text("Export data"),
        ),
        Visibility(
            visible: showBackupProgress,
            child: OverallExportProgressWidget(
              contactsExported: contactsExported,
              contactsTotal: contactsAmountDatabase,
              smsExported: smsMessagesExported,
              smsTotal: smsMessageCount,
              callLogsExported: callLogsExported,
              callLogsTotal: callLogsAmount,
            )),
        const Divider(
          color: Color.fromARGB(31, 44, 44, 44),
          height: 25,
          thickness: 1,
          indent: 5,
          endIndent: 5,
        ),
        // data import section
        Row(
          children: const [
            Icon(Icons.file_download, size: 24, color: Colors.green),
            SizedBox(width: 8),
            Text(
              "Import Contacts",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Text(
          "Upon restoring a backup, press the button below to automatically import all contacts. SMS message importing isn't currently available, but you can view your messages by opening your backup archive.",
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              showRestoreProgress = true;
            });
            autoRestoreContacts(context);
          },
          child: const Text("Auto-restore contacts"),
        ),
        Visibility(
            visible: showRestoreProgress,
            child: ImportProgressWidget(
              contactsImported: contactsImported,
              contactsTotal: contactsAmountFilesystem,
            )),
      ],
    );
  }
}
