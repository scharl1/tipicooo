import 'package:flutter/material.dart';

class NotificationState {
  // 👇 Indica se ci sono notifiche non lette
  static ValueNotifier<bool> hasUnread = ValueNotifier(false);
}