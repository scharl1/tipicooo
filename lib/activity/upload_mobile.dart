import 'package:image_picker/image_picker.dart';

Future<String?> pickImage() async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.gallery);
  return picked?.path;
}