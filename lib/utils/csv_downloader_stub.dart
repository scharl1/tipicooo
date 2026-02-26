import 'package:share_plus/share_plus.dart';

Future<void> downloadCsv({
  required String filename,
  required String csvContent,
}) async {
  // MVP: share the CSV text (mobile/desktop). Web uses a real download.
  await Share.share(csvContent, subject: filename);
}

