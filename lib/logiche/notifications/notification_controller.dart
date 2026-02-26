import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';

import 'app_notification.dart';

class NotificationController extends ChangeNotifier {
  NotificationController._internal();
  static final NotificationController instance =
      NotificationController._internal();

  final List<AppNotification> _notifications = [];
  late Box _box;
  String _storageKey = 'list_guest';
  bool _authListenerAttached = false;

  Future<void> init() async {
    _box = Hive.box('notifications');
    if (!_authListenerAttached) {
      AuthState.isLoggedIn.addListener(_onAuthStateChanged);
      _authListenerAttached = true;
    }
    await _switchStorageByCurrentUser();
    _loadFromStorage();
  }

  Future<void> _onAuthStateChanged() async {
    await _switchStorageByCurrentUser();
    _loadFromStorage();
  }

  Future<void> _switchStorageByCurrentUser() async {
    final userId = AuthState.userId.trim();
    final nextKey = userId.isEmpty ? 'list_guest' : 'list_user_$userId';
    _storageKey = nextKey;
  }

  void _loadFromStorage() {
    final stored = _box.get(_storageKey, defaultValue: []);

    _notifications.clear();
    if (stored is List) {
      for (final item in stored) {
        if (item is Map) {
          _notifications.add(
            AppNotification.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    notifyListeners();
    unawaited(_syncAppIconBadge());
  }

  void _saveToStorage() {
    final data = _notifications.map((n) => n.toMap()).toList();
    _box.put(_storageKey, data);
  }

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  bool get hasUnread => _notifications.any((n) => !n.read);
  int get unreadCount => _notifications.where((n) => !n.read).length;

  Future<void> _syncAppIconBadge() async {
    if (kIsWeb) return;
    try {
      final supported = await FlutterAppBadger.isAppBadgeSupported();
      if (!supported) return;
      final count = unreadCount;
      if (count > 0) {
        await FlutterAppBadger.updateBadgeCount(count);
      } else {
        await FlutterAppBadger.removeBadge();
      }
    } catch (_) {
      // No-op: alcuni launcher non supportano badge.
    }
  }

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    _saveToStorage();
    notifyListeners();
    unawaited(_syncAppIconBadge());
  }

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
      unawaited(_syncAppIconBadge());
    }
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _saveToStorage();
    notifyListeners();
    unawaited(_syncAppIconBadge());
  }

  void deleteNotificationsByAction(String action) {
    final before = _notifications.length;
    _notifications.removeWhere((n) => n.action == action);
    if (_notifications.length != before) {
      _saveToStorage();
      notifyListeners();
      unawaited(_syncAppIconBadge());
    }
  }

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

