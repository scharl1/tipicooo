import 'dart:io';
import 'dart:typed_data';

Uint8List? readFileBytesImpl(String path) {
  try {
    final file = File(path);
    return file.readAsBytesSync();
  } catch (_) {
    return null;
  }
}
