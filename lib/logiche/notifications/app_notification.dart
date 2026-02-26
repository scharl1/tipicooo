class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  bool read;
  final String? action;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.read = false,
    this.action,
  });

  // ⭐ Per salvataggio su Hive
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
      'action': action,
    };
  }

  // ⭐ Per ricostruire l’oggetto da Hive
  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      read: (map['read'] as bool?) ?? false,
      action: map['action'] as String?,
    );
  }

  @override
  String toString() {
    return 'AppNotification(id: $id, title: $title, read: $read, timestamp: $timestamp)';
  }
}
