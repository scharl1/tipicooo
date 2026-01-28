import 'package:hive_flutter/hive_flutter.dart';
import 'hive_boxes.dart';

class HiveRegisterActivity {
  static Box get box => Hive.box(HiveBoxes.registerActivity);

  // ⭐ Salva un campo generico
  static void saveField(String key, dynamic value) {
    box.put(key, value);
  }

  // ⭐ Legge un campo
  static dynamic loadField(String key) {
    return box.get(key);
  }

  // ⭐ Aggiunge una foto (max 10)
  static void addPhoto(String path) {
    final List photos = box.get('foto', defaultValue: []);
    if (photos.length < 10) {
      photos.add(path);
      box.put('foto', photos);
    }
  }

  // ⭐ Rimuove una foto
  static void removePhoto(String path) {
    final List photos = box.get('foto', defaultValue: []);
    photos.remove(path);
    box.put('foto', photos);
  }

  // ⭐ Salva visura camerale
  static void saveVisura(String path) {
    box.put('visura', path);
  }

  // ⭐ Pulisce tutto dopo l’invio
  static void clearAll() {
    box.clear();
  }
}