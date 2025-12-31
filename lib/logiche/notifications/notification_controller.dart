import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_notification.dart';

class NotificationController extends ChangeNotifier {
  NotificationController._internal();
  static final NotificationController instance = NotificationController._internal();

  final List<AppNotification> _notifications = [];
  late Box _box;

  // ⭐ Inizializzazione Hive per questo controller
  Future<void> init() async {
    _box = Hive.box('notifications');
    _loadFromStorage();
  }

  // ⭐ Carica notifiche salvate
  void _loadFromStorage() {
    final stored = _box.get('list', defaultValue: []);

    if (stored is List) {
      _notifications.clear();
      for (final item in stored) {
        if (item is Map) {
          _notifications.add(
            AppNotification.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
      notifyListeners();
    }
  }

  // ⭐ Salva notifiche su Hive
  void _saveToStorage() {
    final data = _notifications.map((n) => n.toMap()).toList();
    _box.put('list', data);
  }

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  bool get hasUnread => _notifications.any((n) => !n.read);

  // ⭐ Aggiungi una notifica
  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    _saveToStorage();
    notifyListeners();
  }

  // ⭐ Marca tutte come lette
  void markAllAsRead() {
    bool changed = false;
    for (final n in _notifications) {
      if (!n.read) {
        n.read = true;
        changed = true;
      }
    }
    if (changed) {
      _saveToStorage();
      notifyListeners();
    }
  }

  // ⭐ Elimina una notifica
  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _saveToStorage();
    notifyListeners();
  }

  // ⭐ Per debug
  void addDebugNotification(String message) {
    final n = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Notifica Tipicooo',
      message: message,
      timestamp: DateTime.now(),
    );
    addNotification(n);
    debugPrint('Notifica aggiunta: $n');
  }
}