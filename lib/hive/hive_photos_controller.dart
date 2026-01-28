import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'hive_boxes.dart';

class HivePhotosController extends ChangeNotifier {
  List<String> photos = [];

  HivePhotosController() {
    loadPhotos();
  }

  // ⭐ Carica foto da Hive
  void loadPhotos() {
    final box = Hive.box(HiveBoxes.registerActivity);
    photos = List<String>.from(box.get('foto', defaultValue: []));
    notifyListeners();
  }

  // ⭐ Salva foto su Hive
  void _save() {
    final box = Hive.box(HiveBoxes.registerActivity);
    box.put('foto', photos);
  }

  // ⭐ Aggiungi foto (max 10)
  void addPhoto(String path) {
    if (photos.length >= 10) return;
    photos.add(path);
    _save();
    notifyListeners();
  }

  // ⭐ Rimuovi foto
  void removePhoto(String path) {
    photos.remove(path);
    _save();
    notifyListeners();
  }

  // ⭐ Numero foto
  int get count => photos.length;

  // ⭐ Mostrare il box "+"?
  bool get showAddBox => photos.length < 10;

  // ⭐ Cancella tutte le foto (necessario per RegisterActivityPage)
  void clearAll() {
    photos.clear();
    _save();
    notifyListeners();
  }
}