import 'dart:typed_data';

import 'package:camera/camera.dart';

class CapturedImage {
  final Uint8List bytes;
  final String filename;

  const CapturedImage({required this.bytes, required this.filename});

  static Future<CapturedImage> fromXFile(
    XFile file, {
    required String fallbackPrefix,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final normalizedPath = file.path.replaceAll('\\', '/');
    final inferredName = normalizedPath.isEmpty
        ? ''
        : normalizedPath.split('/').last;

    final filename =
        inferredName.isNotEmpty &&
            !inferredName.startsWith('blob:') &&
            inferredName.contains('.')
        ? inferredName
        : '${fallbackPrefix}_$timestamp.jpg';

    return CapturedImage(bytes: await file.readAsBytes(), filename: filename);
  }
}
