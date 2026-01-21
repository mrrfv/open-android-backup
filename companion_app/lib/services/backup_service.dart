import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:csv/csv.dart';
import 'package:call_log/call_log.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import './file_service.dart';
import './preferences_service.dart';

class BackupService {
  final FileService _fileService = FileService();
  final PreferencesService _prefsService = PreferencesService();

  // Progress callbacks
  Function(int, int)? onContactsProgress;
  Function(int, int)? onSmsProgress;
  Function(int, int)? onCallLogsProgress;
  Function(int, int)? onImportProgress;

  /// Check if we have necessary permissions for contacts operations
  Future<bool> _checkContactsPermission() async {
    return await FlutterContacts.requestPermission();
  }

  /// Check if we have necessary permissions for SMS operations
  Future<bool> _checkSmsPermission() async {
    return await Permission.sms.request().isGranted;
  }

  /// Export contacts to the specified directory
  Future<bool> exportContacts(String directoryPath) async {
    // Check contacts permission first
    if (!(await _checkContactsPermission())) {
      return false;
    }

    try {
      final List<Contact> contacts = await FlutterContacts.getContacts(
          withProperties: true, withPhoto: true, withGroups: true);

      if (onContactsProgress != null) {
        onContactsProgress!(0, contacts.length);
      }

      // Export each contact
      for (var i = 0; i < contacts.length; i++) {
        final String vCard = contacts[i].toVCard(withPhoto: true);
        final fileName = 'open-android-backup-contact-$i.vcf';

        final exportedPath = await _fileService.exportFile(
          directoryPath: directoryPath,
          fileName: fileName,
          content: vCard,
        );

        if (exportedPath == null) {
          // DEBUG: Failed to export contact $i
          return false;
        }

        if (onContactsProgress != null) {
          onContactsProgress!(i + 1, contacts.length);
        }
      }

      return true;
    } catch (e) {
      // Error exporting contacts: $e
      return false;
    }
  }

  /// Export SMS messages to the specified directory
  Future<bool> exportSms(String directoryPath) async {
    // Check SMS permission first
    if (!(await _checkSmsPermission())) {
      return false;
    }

    try {
      final SmsQuery sms = SmsQuery();
      List<SmsMessage> messages = await sms.getAllSms;

      if (onSmsProgress != null) {
        onSmsProgress!(0, messages.length);
      }

      // Process messages for CSV
      List<List<String>> processedMessages = [];
      processedMessages.add(["ID", "Address", "Body", "Date"]);

      for (var i = 0; i < messages.length; i++) {
        List<String> message = [
          messages[i].id.toString(),
          messages[i].address.toString(),
          messages[i].body.toString(),
          messages[i].date.toString(),
        ];
        processedMessages.add(message);

        if (onSmsProgress != null) {
          onSmsProgress!(i + 1, messages.length);
        }
      }

      String csvProcessedMessages = const ListToCsvConverter().convert(processedMessages);

      // Export SMS CSV
      final exportedPath = await _fileService.exportFile(
        directoryPath: directoryPath,
        fileName: 'SMS_Messages.csv',
        content: csvProcessedMessages,
      );

      return exportedPath != null;
    } catch (e) {
      // Error exporting SMS: $e
      return false;
    }
  }

  /// Export call logs to the specified directory
  Future<bool> exportCallLogs(String directoryPath) async {
    try {
      Iterable<CallLogEntry> entries = await CallLog.get();

      if (onCallLogsProgress != null) {
        onCallLogsProgress!(0, entries.length);
      }

      // Process call logs for CSV
      List<List<String>> processedCallLogs = [];
      processedCallLogs.add(["Number", "Name", "Date", "Duration"]);

      for (var i = 0; i < entries.length; i++) {
        List<String> callLog = [
          entries.elementAt(i).number.toString(),
          entries.elementAt(i).name.toString(),
          entries.elementAt(i).timestamp.toString(),
          entries.elementAt(i).duration.toString(),
        ];
        processedCallLogs.add(callLog);

        if (onCallLogsProgress != null) {
          onCallLogsProgress!(i + 1, entries.length);
        }
      }

      String csvCallLogs = const ListToCsvConverter().convert(processedCallLogs);

      // Export call logs CSV
      final exportedPath = await _fileService.exportFile(
        directoryPath: directoryPath,
        fileName: 'Call_Logs.csv',
        content: csvCallLogs,
      );

      return exportedPath != null;
    } catch (e) {
      // Error exporting call logs: $e
      return false;
    }
  }

  /// Import contacts from the specified directory
  Future<bool> importContacts(String directoryPath) async {
    // Check contacts permission first
    if (!(await _checkContactsPermission())) {
      return false;
    }

    try {
      final List<File> files = await _fileService.getFilesFromDirectory(directoryPath);

      if (onImportProgress != null) {
        onImportProgress!(0, files.length);
      }

      int importedCount = 0;

      for (var i = 0; i < files.length; i++) {
        if (files[i].path.endsWith(".vcf")) {
          final String vcard = await _fileService.readFile(files[i].path) ?? '';
          if (vcard.isNotEmpty) {
            final Contact contact = Contact.fromVCard(vcard);
            await contact.insert();
            importedCount++;
          }
        }

        if (onImportProgress != null) {
          onImportProgress!(i + 1, files.length);
        }
      }

      return importedCount > 0;
    } catch (e) {
      // Error importing contacts: $e
      return false;
    }
  }

  /// Request export directory using file picker
  Future<String?> requestExportDirectory(BuildContext context) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      await _prefsService.setExportDirectory(selectedDirectory);
      return selectedDirectory;
    }

    return null;
  }

  /// Request import directory using file picker
  Future<String?> requestImportDirectory(BuildContext context) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      await _prefsService.setImportDirectory(selectedDirectory);
      return selectedDirectory;
    }

    return null;
  }

  /// Get export directory from preferences
  Future<String?> getExportDirectory() async {
    return await _prefsService.getExportDirectory();
  }

  /// Get import directory from preferences
  Future<String?> getImportDirectory() async {
    return await _prefsService.getImportDirectory();
  }

  /// Save export preferences
  Future<void> saveExportPreferences({
    required bool exportContacts,
    required bool exportSms,
    required bool exportCallLogs,
  }) async {
    await _prefsService.saveExportPreferences(
      exportContacts: exportContacts,
      exportSms: exportSms,
      exportCallLogs: exportCallLogs,
    );
  }

  /// Get export preferences
  Future<Map<String, bool>> getExportPreferences() async {
    return await _prefsService.getExportPreferences();
  }

  /// Clear all preferences
  Future<void> clearPreferences() async {
    await _prefsService.clearPreferences();
  }
}
