import 'dart:html' as html;

Future<String?> pickImage() async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();

  await input.onChange.first;

  final file = input.files?.first;
  if (file == null) return null;

  final reader = html.FileReader();
  reader.readAsDataUrl(file);

  await reader.onLoadEnd.first;

  return reader.result as String?;
}