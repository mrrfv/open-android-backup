import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:csv/csv.dart';
import "dart:io";

import 'package:device_info_plus/device_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linux Android Backup',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      darkTheme:
          ThemeData(primarySwatch: Colors.green, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // for backups
  bool showBackupProgress = false;
  int contactsAmountDatabase = 0;
  int contactsExported = 0;
  int smsMessageCount = 0;
  int smsMessagesExported = 0;
  // for restores
  bool showRestoreProgress = false;
  int contactsAmountFilesystem = 0;
  int contactsImported = 0;

  Future<void> backup(BuildContext context) async {
    // Requests contacts & internal storage permissions
    if (await FlutterContacts.requestPermission() &&
        await Permission.storage.request().isGranted &&
        await Permission.sms.request().isGranted) {
      // create an instance of the SmsQuery class
      SmsQuery sms = SmsQuery();

      // On Android 11 and later, request additional permissions.
      if ((await DeviceInfoPlugin().androidInfo).version.sdkInt! > 29 &&
          !await Permission.manageExternalStorage.request().isGranted) {
        // Open app settings if the permission wasn't granted
        await openAppSettings();
      }

      // Show a snackbar notifying the user that the export has started
      // (provides feedback just in case there are a lot of contacts to export)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data export has started.")));

      // Get all contacts
      final List<Contact> contacts = await FlutterContacts.getContacts(
          withProperties: true, withPhoto: true, withGroups: true);

      setState(() {
        contactsAmountDatabase = contacts.length;
      });

      // Recreate the temp directory if it already exists.
      final Directory directory =
          Directory("/storage/emulated/0/linux-android-backup-temp");
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await directory.create();

      // Loop over the contacts and save them as a vCard.
      for (var i = 0; i < contacts.length; i++) {
        final String vCard = contacts[i].toVCard(withPhoto: true);
        final File file = File(
            "/storage/emulated/0/linux-android-backup-temp/linux-android-backup-contact-$i.vcf");
        file.writeAsString(vCard);
        setState(() {
          contactsExported = i + 1;
        });
      }

      // Export SMS messages.
      List<SmsMessage> messages = await sms.getAllSms;

      setState(() {
        smsMessageCount = messages.length;
      });

      // Process messages so they can be saved to a CSV file.
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
        setState(() {
          smsMessagesExported = i + 1;
        });
      }
      String csv = const ListToCsvConverter().convert(processedMessages);

      final File sms_file_export = File(
          "/storage/emulated/0/linux-android-backup-temp/SMS_Messages.csv");
      sms_file_export.writeAsString(csv);

      // Show a dialog if the export is complete
      showInfoDialog(context, "Data Exported",
          "Please continue the backup process on your computer.");
    } else {
      showInfoDialog(context, "Error",
          "Storage, SMS or contacts permissions have not been granted.");
    }
  }

  Future<void> autoRestoreContacts(BuildContext context) async {
    // Requests contacts & internal storage permissions
    if (await FlutterContacts.requestPermission() &&
        await Permission.storage.request().isGranted) {
      // On Android 11 and later, request additional permissions.
      if ((await DeviceInfoPlugin().androidInfo).version.sdkInt! > 29 &&
          !await Permission.manageExternalStorage.request().isGranted) {
        // Open app settings if the permission wasn't granted
        await openAppSettings();
      }

      final contactsDir = Directory("/storage/emulated/0/Contacts_Backup");
      if (await contactsDir.exists()) {
        // Show a snackbar notifying the user that the import has started
        // (provides feedback just in case there are a lot of contacts to import)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Data import has started.")));

        // List directory contents
        final List<FileSystemEntity> files = await contactsDir.list().toList();

        setState(() {
          contactsAmountFilesystem = files.length;
        });

        // Loop over the contents
        for (var i = 0; i < files.length; i++) {
          if (files[i] is File) {
            // If the entity is a file, read its contents as a vCard and insert it into Android's contact database
            final String vcard = await (files[i] as File).readAsString();
            final Contact contact = Contact.fromVCard(vcard);
            await contact.insert();
          }

          setState(() {
            contactsImported = i + 1;
          });
        }

        showInfoDialog(context, "Success", "Data has been imported.");
      } else {
        showInfoDialog(context, "Error",
            "The contact backup directory couldn't be found.");
      }
    } else {
      showInfoDialog(context, "Error",
          "Storage and/or contacts permissions have not been granted.");
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linux Android Backup Companion'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            const Text(
              "The Linux Android Backup companion app allows for backups of your contacts, with more to come. It doesn't upload your data to a remote server: data is saved to the internal storage and then read by the script running on your computer.",
            ),
            const Text("This app requires a computer as well as the Linux Android Backup script running."),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  showBackupProgress = true;
                });
                backup(context);
              },
              child: const Text("Export Data"),
            ),
            Visibility(
                visible: showBackupProgress,
                child: Text("Exported " +
                    contactsExported.toString() +
                    " contact(s) out of " +
                    contactsAmountDatabase.toString() +
                    ". Found " +
                    smsMessageCount.toString() +
                    " SMS messages to process, of which " +
                    smsMessagesExported.toString() +
                    " have been exported.")),
            const Divider(
              color: Color.fromARGB(31, 44, 44, 44),
              height: 25,
              thickness: 1,
              indent: 5,
              endIndent: 5,
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
                child: Text("Restored " +
                    contactsImported.toString() +
                    " contact(s) out of " +
                    contactsAmountFilesystem.toString() +
                    ".")),
          ],
        ),
      ),
    );
  }
}
