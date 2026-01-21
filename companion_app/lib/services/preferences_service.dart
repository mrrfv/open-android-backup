import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _exportContactsKey = 'export_contacts';
  static const String _exportSmsKey = 'export_sms';
  static const String _exportCallLogsKey = 'export_call_logs';

  /// Save export preferences
  Future<void> saveExportPreferences({
    required bool exportContacts,
    required bool exportSms,
    required bool exportCallLogs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_exportContactsKey, exportContacts);
    await prefs.setBool(_exportSmsKey, exportSms);
    await prefs.setBool(_exportCallLogsKey, exportCallLogs);
  }

  /// Get export preferences
  Future<Map<String, bool>> getExportPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'exportContacts': prefs.getBool(_exportContactsKey) ?? true,
      'exportSms': prefs.getBool(_exportSmsKey) ?? true,
      'exportCallLogs': prefs.getBool(_exportCallLogsKey) ?? true,
    };
  }

  /// Clear all preferences
  Future<void> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Set export directory
  Future<void> setExportDirectory(String directoryPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('export_directory', directoryPath);
  }

  /// Set import directory
  Future<void> setImportDirectory(String directoryPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('import_directory', directoryPath);
  }

  /// Get export directory
  Future<String?> getExportDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('export_directory');
  }

  /// Get import directory
  Future<String?> getImportDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('import_directory');
  }
}
