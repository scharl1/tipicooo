// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadCsv({
  required String filename,
  required String csvContent,
}) async {
  final bytes = utf8.encode(csvContent);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
