import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/attachment.dart';

/// Copies picked documents into the app's documents directory and resolves
/// them back to [File]s. Everything stays on-device; only a relative path is
/// persisted so files keep resolving if the app container path changes.
class AttachmentService {
  AttachmentService._();
  static final AttachmentService instance = AttachmentService._();

  static const _subdir = 'attachments';

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_subdir');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Resolves an attachment's on-device [File].
  Future<File> fileFor(Attachment a) async {
    final base = await getApplicationDocumentsDirectory();
    return File('${base.path}/${a.relativePath}');
  }

  /// Copies [sourcePath] into the app dir and returns the stored [Attachment].
  Future<Attachment> importFile({
    required String id,
    required String sourcePath,
    required String displayName,
  }) async {
    await _dir(); // ensure the attachments directory exists
    final dotExt = displayName.contains('.') ? displayName.split('.').last.toLowerCase() : '';
    final stored = '$_subdir/$id${dotExt.isEmpty ? '' : '.$dotExt'}';
    final base = await getApplicationDocumentsDirectory();
    await File(sourcePath).copy('${base.path}/$stored');
    return Attachment(id: id, fileName: displayName, relativePath: stored, ext: dotExt);
  }

  Future<void> delete(Attachment a) async {
    try {
      final f = await fileFor(a);
      if (f.existsSync()) await f.delete();
    } catch (e) {
      debugPrint('Attachment delete failed: $e');
    }
  }

  Future<void> deleteAll(Iterable<Attachment> attachments) async {
    for (final a in attachments) {
      await delete(a);
    }
  }
}
