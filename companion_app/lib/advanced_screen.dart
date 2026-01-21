import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import './services/preferences_service.dart';
import './services/backup_service.dart';
import './widgets/progress_widgets.dart';

class AdvancedScreen extends StatefulWidget {
  const AdvancedScreen({Key? key}) : super(key: key);

  @override
  State<AdvancedScreen> createState() => _AdvancedScreenState();
}

class _AdvancedScreenState extends State<AdvancedScreen> {
  final PreferencesService _prefsService = PreferencesService();
  final BackupService _backupService = BackupService();

  // Export state
  bool _exportContacts = true;
  bool _exportSms = true;
  bool _exportCallLogs = true;
  bool _showExportProgress = false;
  int _contactsExported = 0;
  int _contactsTotal = 0;
  int _smsExported = 0;
  int _smsTotal = 0;
  int _callLogsExported = 0;
  int _callLogsTotal = 0;

  // Import state
  bool _showImportProgress = false;
  int _contactsImported = 0;
  int _contactsImportTotal = 0;

  // Directory paths
  String? _exportDirectoryPath;
  String? _importDirectoryPath;

  /// Compact a file path for display
  String _compactPath(String path) {
    // Remove common prefixes
    if (path.startsWith('/storage/emulated/0/')) {
      path = path.replaceFirst('/storage/emulated/0/', '');
    }
    if (path.startsWith('/sdcard/')) {
      path = path.replaceFirst('/sdcard/', '');
    }

    // If path is still long, show first and last parts
    if (path.length > 30) {
      final parts = path.split('/');
      if (parts.length > 2) {
        return '${parts.first}/.../${parts.last}';
      }
    }

    return path;
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadDirectoryPreferences();

    // Set up progress callbacks
    _backupService.onContactsProgress = (current, total) {
      setState(() {
        _contactsExported = current;
        _contactsTotal = total;
      });
    };

    _backupService.onSmsProgress = (current, total) {
      setState(() {
        _smsExported = current;
        _smsTotal = total;
      });
    };

    _backupService.onCallLogsProgress = (current, total) {
      setState(() {
        _callLogsExported = current;
        _callLogsTotal = total;
      });
    };

    _backupService.onImportProgress = (current, total) {
      setState(() {
        _contactsImported = current;
        _contactsImportTotal = total;
      });
    };
  }

  Future<void> _loadPreferences() async {
    final prefs = await _prefsService.getExportPreferences();
    setState(() {
      _exportContacts = prefs['exportContacts'] ?? true;
      _exportSms = prefs['exportSms'] ?? true;
      _exportCallLogs = prefs['exportCallLogs'] ?? true;
    });
  }

  Future<void> _loadDirectoryPreferences() async {
    final exportDir = await _prefsService.getExportDirectory();
    final importDir = await _prefsService.getImportDirectory();
    setState(() {
      _exportDirectoryPath = exportDir;
      _importDirectoryPath = importDir;
    });
  }

  Future<void> _savePreferences() async {
    await _prefsService.saveExportPreferences(
      exportContacts: _exportContacts,
      exportSms: _exportSms,
      exportCallLogs: _exportCallLogs,
    );
  }

  Future<void> _requestExportDirectory() async {
    // Use file picker to select export directory
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      setState(() {
        _exportDirectoryPath = selectedDirectory;
      });
      await _prefsService.setExportDirectory(selectedDirectory);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export directory selected successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to select export directory.')),
      );
    }
  }

  Future<void> _requestImportDirectory() async {
    // Use file picker to select import directory
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      setState(() {
        _importDirectoryPath = selectedDirectory;
      });
      await _prefsService.setImportDirectory(selectedDirectory);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import directory selected successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to select import directory.')),
      );
    }
  }

  Future<void> _exportData() async {
    print('DEBUG: Starting export process');

    // Check if we have export directory
    if (_exportDirectoryPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an export directory first.')),
      );
      print('DEBUG: No export directory selected, aborting');
      return;
    }

    // Get export directory
    final exportDir = _exportDirectoryPath!;
    print('DEBUG: Export directory: $exportDir');

    setState(() {
      _showExportProgress = true;
      _contactsExported = 0;
      _smsExported = 0;
      _callLogsExported = 0;
      _contactsTotal = 0;
      _smsTotal = 0;
      _callLogsTotal = 0;
    });

    try {
      print('DEBUG: Starting data export process');

      // Export contacts if enabled
      if (_exportContacts) {
        print('DEBUG: Starting contacts export');
        final success = await _backupService.exportContacts(exportDir);
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to export contacts.')),
          );
          return;
        }
        print('DEBUG: Contacts export completed');
      }

      // Export SMS if enabled
      if (_exportSms) {
        print('DEBUG: Starting SMS export');
        final success = await _backupService.exportSms(exportDir);
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to export SMS messages.')),
          );
          return;
        }
        print('DEBUG: SMS export completed');
      }

      // Export call logs if enabled
      if (_exportCallLogs) {
        print('DEBUG: Starting call logs export');
        final success = await _backupService.exportCallLogs(exportDir);
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to export call logs.')),
          );
          return;
        }
        print('DEBUG: Call logs export completed');
      }

      print('DEBUG: All exports completed successfully');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export completed successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _showExportProgress = false;
      });
    }
  }

  Future<void> _importContacts() async {
    // Check if we have import directory
    if (_importDirectoryPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an import directory first.')),
      );
      return;
    }

    setState(() {
      _showImportProgress = true;
      _contactsImported = 0;
      _contactsImportTotal = 0;
    });

    try {
      final success = await _backupService.importContacts(_importDirectoryPath!);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import completed successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No contacts were imported.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _showImportProgress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom Backup',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Export and import data independently of the backup script.',
            ),
            const SizedBox(height: 24),

            // Export Section
            const Text(
              'Export',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Directory Selection
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _requestExportDirectory,
                    icon: const Icon(Icons.folder_open),
                    label: _exportDirectoryPath != null
                        ? Text(_compactPath(_exportDirectoryPath!))
                        : const Text('Select Export Directory'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Export Directory'),
                        content: const Text('Select where you want to export your data. The app will remember this location.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Data Type Toggles
            const Text('Data to Export:'),
            CheckboxListTile(
              title: const Text('Contacts (.vcf)'),
              value: _exportContacts,
              onChanged: (value) {
                setState(() {
                  _exportContacts = value ?? true;
                });
                _savePreferences();
              },
            ),
            CheckboxListTile(
              title: const Text('SMS Messages (.csv)'),
              value: _exportSms,
              onChanged: (value) {
                setState(() {
                  _exportSms = value ?? true;
                });
                _savePreferences();
              },
            ),
            CheckboxListTile(
              title: const Text('Call Logs (.csv)'),
              value: _exportCallLogs,
              onChanged: (value) {
                setState(() {
                  _exportCallLogs = value ?? true;
                });
                _savePreferences();
              },
            ),
            const SizedBox(height: 16),

            // Export Button
            ElevatedButton.icon(
              onPressed: _exportData,
              icon: const Icon(Icons.file_upload),
              label: const Text('Export Selected Data'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 8),

            // Export Progress
            if (_showExportProgress) ...[
              const SizedBox(height: 16),
              OverallExportProgressWidget(
                contactsExported: _exportContacts ? _contactsExported : 0,
                contactsTotal: _exportContacts ? _contactsTotal : 0,
                smsExported: _exportSms ? _smsExported : 0,
                smsTotal: _exportSms ? _smsTotal : 0,
                callLogsExported: _exportCallLogs ? _callLogsExported : 0,
                callLogsTotal: _exportCallLogs ? _callLogsTotal : 0,
              ),
            ],

            const Divider(height: 32),

            // Import Section
            const Text(
              'Import',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Import Directory Selection
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _requestImportDirectory,
                    icon: const Icon(Icons.folder_open),
                    label: _importDirectoryPath != null
                        ? Text(_compactPath(_importDirectoryPath!))
                        : const Text('Select Import Directory'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Import Directory'),
                        content: const Text('Select the directory containing contacts to import. The app expects vCard (.vcf) files.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Import Button
            ElevatedButton.icon(
              onPressed: _importContacts,
              icon: const Icon(Icons.file_download),
              label: const Text('Import Contacts'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 8),

            // Import Progress
            if (_showImportProgress) ...[
              const SizedBox(height: 16),
              ImportProgressWidget(
                contactsImported: _contactsImported,
                contactsTotal: _contactsImportTotal,
              ),
            ],

            const Divider(height: 32),

            // Settings Section
            const Text(
              'Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Settings'),
                    content: const Text('This will clear all your preferences.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _prefsService.clearPreferences();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings cleared successfully!')),
                          );
                          // Reset state
                          setState(() {
                            _exportContacts = true;
                            _exportSms = true;
                            _exportCallLogs = true;
                          });
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete),
              label: const Text('Clear All Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 224, 130, 6),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
