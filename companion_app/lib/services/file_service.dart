import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class FileService {
  /// Check if we have necessary storage permissions for file operations
  Future<bool> checkStoragePermissions() async {
    // Check storage permissions based on Android version
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt <= 29) {
      if (!(await Permission.storage.request().isGranted)) {
        return false;
      }
    } else {
      if (!(await Permission.manageExternalStorage.request().isGranted)) {
        return false;
      }
    }

    return true;
  }

  /// Verify that we have permissions and the directory is accessible
  Future<bool> verifyDirectoryAccess(String directoryPath) async {
    // First check storage permissions
    if (!(await checkStoragePermissions())) {
      return false;
    }

    // Then check if directory is accessible
    try {
      final dir = Directory(directoryPath);
      return await dir.exists();
    } catch (e) {
      // Error checking directory accessibility: $e
      return false;
    }
  }

  /// Export a file to the specified directory
  Future<String?> exportFile({
    required String directoryPath,
    required String fileName,
    required String content,
  }) async {
    try {
      // First verify we have permissions and directory is accessible
      if (!(await verifyDirectoryAccess(directoryPath))) {
      // DEBUG: No permissions or directory not accessible
        return null;
      }

      // Create the directory if it doesn't exist
      final exportDir = Directory(directoryPath);
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // Create the file
      final file = File('${exportDir.path}/$fileName');
      await file.writeAsString(content);

      // DEBUG: Exported file to: ${file.path}
      return file.path;
    } catch (e) {
      // Error exporting file: $e
      // Stack trace: ${StackTrace.current}
      return null;
    }
  }

  /// Get files from a directory with permission check
  Future<List<File>> getFilesFromDirectory(String directoryPath) async {
    try {
      // First verify we have permissions and directory is accessible
      if (!(await verifyDirectoryAccess(directoryPath))) {
        // DEBUG: No permissions or directory not accessible
        return [];
      }

      final dir = Directory(directoryPath);
      if (await dir.exists()) {
        final List<FileSystemEntity> entities = await dir.list().toList();
        return entities.whereType<File>().toList();
      }
      return [];
    } catch (e) {
      // Error getting files from directory: $e
      return [];
    }
  }

  /// Read file content with permission check
  Future<String?> readFile(String filePath) async {
    try {
      // Verify we have storage permissions
      if (!(await checkStoragePermissions())) {
        // DEBUG: No storage permissions to read file
        return null;
      }

      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      // Error reading file: $e
      return null;
    }
  }
}
