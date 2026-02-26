// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';

class OfficeNotificationsPage extends StatefulWidget {
  const OfficeNotificationsPage({super.key});

  @override
  State<OfficeNotificationsPage> createState() => _OfficeNotificationsPageState();
}

class _OfficeNotificationsPageState extends State<OfficeNotificationsPage> {
  static const String _officeBase =
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod";
  static const String _activityBase =
      "https://efs0gx9nm4.execute-api.eu-south-1.amazonaws.com/prod";
  static const String _seenNotificationsKey = "officeSeenNotifications";

  late Future<List<_OfficeNotificationItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadNotifications();
  }

  Future<List<_OfficeNotificationItem>> _loadNotifications() async {
    final token = OfficeAuth.token;
    if (token == null || token.isEmpty) return const [];

    final seenIds = _readSeenNotificationIds();
    final headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
    final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

    final adminUrl = Uri.parse("$_officeBase/admin-list-requests?_=$cacheBuster");
    final activityUrl = Uri.parse(
      "$_activityBase/activity-requests?status=pending&_=$cacheBuster",
    );
    final usersUrl = Uri.parse("$_officeBase/admin-new-users-list?limit=100&_=$cacheBuster");
    final deletedUsersUrl = Uri.parse("$_officeBase/deleted-users-list?limit=100&_=$cacheBuster");
    final rejectedUrl = Uri.parse(
      "$_officeBase/admin-purchase-rejected-count?sinceAt=&_=$cacheBuster",
    );

    final results = await Future.wait([
      http.get(adminUrl, headers: headers),
      http.get(activityUrl, headers: headers),
      http.get(usersUrl, headers: headers),
      http.get(deletedUsersUrl, headers: headers),
      http.get(rejectedUrl, headers: headers),
    ]);

    final notifications = <_OfficeNotificationItem>[];

    if (results[0].statusCode == 200) {
      final data = jsonDecode(results[0].body);
      final items = (data["items"] is List) ? data["items"] as List : <dynamic>[];
      for (final raw in items.whereType<Map>()) {
        final it = Map<String, dynamic>.from(raw);
        final email = (it["email"] ?? "").toString().trim();
        notifications.add(
          _OfficeNotificationItem(
            id:
                "admin:${(it["requestId"] ?? "").toString().trim()}:${(it["createdAt"] ?? "").toString().trim()}:${email.toLowerCase()}",
            title: "Richiesta accesso ufficio",
            message: email.isEmpty ? "Nuova richiesta in attesa." : "Nuova richiesta da $email.",
            createdAt: _parseDate(
              (it["createdAt"] ?? it["updatedAt"] ?? "").toString(),
            ),
            type: "admin",
          ),
        );
      }
    }

    if (results[1].statusCode == 200) {
      final data = jsonDecode(results[1].body);
      final items = (data["items"] is List) ? data["items"] as List : <dynamic>[];
      for (final raw in items.whereType<Map>()) {
        final it = Map<String, dynamic>.from(raw);
        final insegna = (it["insegna"] ?? it["ragione_sociale"] ?? "Attività")
            .toString()
            .trim();
        notifications.add(
          _OfficeNotificationItem(
            id:
                "activity:${(it["requestId"] ?? "").toString().trim()}:${(it["createdAt"] ?? "").toString().trim()}",
            title: "Nuova attività da approvare",
            message: insegna,
            createdAt: _parseDate(
              (it["createdAt"] ?? it["updatedAt"] ?? "").toString(),
            ),
            type: "activity",
          ),
        );
      }
    }

    if (results[2].statusCode == 200) {
      final data = jsonDecode(results[2].body);
      final items = (data["items"] is List) ? data["items"] as List : <dynamic>[];
      for (final raw in items.whereType<Map>()) {
        final it = Map<String, dynamic>.from(raw);
        final email = (it["email"] ?? "").toString().trim();
        notifications.add(
          _OfficeNotificationItem(
            id:
                "users:new:${email.toLowerCase()}:${(it["createdAt"] ?? "").toString().trim()}",
            title: "Nuovo utente registrato",
            message: email.isEmpty ? "Nuovo utente iscritto." : email,
            createdAt: _parseDate((it["createdAt"] ?? "").toString()),
            type: "users",
          ),
        );
      }
    }

    if (results[3].statusCode == 200) {
      final data = jsonDecode(results[3].body);
      final items = (data["items"] is List) ? data["items"] as List : <dynamic>[];
      for (final raw in items.whereType<Map>()) {
        final it = Map<String, dynamic>.from(raw);
        final email = (it["email"] ?? "").toString().trim();
        notifications.add(
          _OfficeNotificationItem(
            id:
                "users:deleted:${email.toLowerCase()}:${(it["deletedAt"] ?? it["createdAt"] ?? "").toString().trim()}",
            title: "Utente eliminato",
            message: email.isEmpty ? "Utente eliminato." : email,
            createdAt: _parseDate(
              (it["deletedAt"] ?? it["createdAt"] ?? "").toString(),
            ),
            type: "users",
          ),
        );
      }
    }

    if (results[4].statusCode == 200) {
      final data = jsonDecode(results[4].body);
      final newCount = (data["newCount"] ?? 0) as int;
      if (newCount > 0) {
        final latestRejectedAt = (data["latestRejectedAt"] ?? "")
            .toString()
            .trim();
        notifications.add(
          _OfficeNotificationItem(
            // ID stabile: se cambia solo il count ma non c'è un nuovo evento,
            // la notifica resta già letta e non riappare.
            id: "activity:rejected:$latestRejectedAt",
            title: "Pagamenti rifiutati",
            message: "Ci sono $newCount pagamenti rifiutati da controllare.",
            createdAt: _parseDate(latestRejectedAt),
            type: "activity",
          ),
        );
      }
    }

    notifications.sort((a, b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return notifications.where((n) => !seenIds.contains(n.id)).toList();
  }

  Set<String> _readSeenNotificationIds() {
    final raw = (html.window.localStorage[_seenNotificationsKey] ?? "").trim();
    if (raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  void _markAsRead(String id) {
    final seen = _readSeenNotificationIds();
    seen.add(id);
    html.window.localStorage[_seenNotificationsKey] = jsonEncode(seen.toList());
  }

  void _removeFromCurrentFuture(String id) {
    setState(() {
      _future = _future.then(
        (items) => items.where((it) => it.id != id).toList(),
      );
    });
  }

  DateTime? _parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return "";
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final h = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "$d/$m/$y $h:$mm";
  }

  Color _typeColor(String type) {
    switch (type) {
      case "admin":
        return Colors.blue.shade700;
      case "activity":
        return Colors.orange.shade700;
      case "users":
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<_OfficeNotificationItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Errore caricamento notifiche."),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _future = _loadNotifications();
                      });
                    },
                    child: const Text("Riprova"),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data ?? const <_OfficeNotificationItem>[];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                "Nessuna notifica admin disponibile.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Notifiche Admin",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: "Aggiorna",
                    onPressed: () {
                      setState(() {
                        _future = _loadNotifications();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    return Dismissible(
                      key: ValueKey(it.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.done, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        _markAsRead(it.id);
                        _removeFromCurrentFuture(it.id);
                      },
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          _markAsRead(it.id);
                          _removeFromCurrentFuture(it.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 6, right: 10),
                                decoration: BoxDecoration(
                                  color: _typeColor(it.type),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      it.message,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    if (it.createdAt != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatDate(it.createdAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OfficeNotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime? createdAt;
  final String type;

  const _OfficeNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.type,
  });
}
