import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden in widget tests with a fake — the real one opens platform
/// file dialogs.
final backupFilesProvider = Provider<BackupFiles>((ref) => const BackupFiles());

/// Thin wrapper around the platform save/open dialogs.
class BackupFiles {
  const BackupFiles();

  /// Lets the user pick a destination and writes [bytes] there.
  /// Returns false when the dialog is cancelled.
  Future<bool> saveAs({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = await FilePicker.saveFile(fileName: fileName, bytes: bytes);
    if (path == null) return false;
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Mobile pickers write the bytes themselves; desktop ones only
      // return the chosen location.
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  }

  /// Lets the user pick a backup file. Returns null when cancelled.
  Future<String?> pickBackupFile() async {
    final result = await FilePicker.pickFiles();
    return result?.files.single.path;
  }
}
