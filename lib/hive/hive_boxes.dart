import 'package:hive_flutter/hive_flutter.dart';
import 'package:tipicooo/models/activity_model.dart';

class HiveBoxes {
  static const String activitiesBox = 'activities_box';

  // ⭐ Inizializzazione globale di Hive
  static Future<void> initHive() async {
    await Hive.initFlutter();

    // Registriamo l'adapter solo se non è già registrato
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ActivityModelAdapter());
    }

    // Apriamo la box delle attività
    await Hive.openBox<ActivityModel>(activitiesBox);
  }

  // Getter rapido per la box
  static Box<ActivityModel> getActivitiesBox() {
    return Hive.box<ActivityModel>(activitiesBox);
  }
}