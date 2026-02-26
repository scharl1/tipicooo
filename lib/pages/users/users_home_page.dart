import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/pages/deleted_users_page.dart';
import 'package:tipicooo_office/pages/users/new_users_page.dart';

class UsersHomePage extends StatefulWidget {
  const UsersHomePage({super.key});

  @override
  State<UsersHomePage> createState() => _UsersHomePageState();
}

class _UsersHomePageState extends State<UsersHomePage> {
  late Future<_UsersStats> futureStats;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    futureStats = _loadStats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String? _getToken() {
    final token = OfficeAuth.token;
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Nessun token admin trovato in localStorage");
    }
    return token;
  }

  Future<_UsersStats> _loadStats() async {
    final token = _getToken();
    if (token == null || token.isEmpty) {
      return const _UsersStats(newUsers: 0, deletedUsers: 0, totalUsers: 0);
    }

    final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
    final newUsersCountUrl = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-new-users-count?_=$cacheBuster",
    );
    final newUsersListUrl = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-new-users-list?limit=500&_=$cacheBuster",
    );
    final deletedUsersUrl = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/deleted-users-list?limit=500&_=$cacheBuster",
    );

    try {
      final headers = <String, String>{
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final results = await Future.wait([
        http.get(newUsersCountUrl, headers: headers),
        http.get(newUsersListUrl, headers: headers),
        http.get(deletedUsersUrl, headers: headers),
      ]);

      final newUsersCountRes = results[0];
      final newUsersListRes = results[1];
      final deletedRes = results[2];

      if (newUsersCountRes.statusCode == 401 ||
          newUsersCountRes.statusCode == 403 ||
          newUsersListRes.statusCode == 401 ||
          newUsersListRes.statusCode == 403 ||
          deletedRes.statusCode == 401 ||
          deletedRes.statusCode == 403) {
        OfficeAuth.clearToken();
        return const _UsersStats(newUsers: 0, deletedUsers: 0, totalUsers: 0);
      }

      int newUsers = 0;
      int deletedUsers = 0;

      if (newUsersCountRes.statusCode == 200) {
        final data = jsonDecode(newUsersCountRes.body);
        if (data["newCount"] is num) {
          newUsers = (data["newCount"] as num).toInt();
        } else if (data["count"] is num) {
          newUsers = (data["count"] as num).toInt();
        } else if (data["total"] is num) {
          newUsers = (data["total"] as num).toInt();
        }
      }

      if (newUsers == 0 && newUsersListRes.statusCode == 200) {
        final data = jsonDecode(newUsersListRes.body);
        final items = (data["items"] is List)
            ? data["items"] as List
            : <dynamic>[];
        newUsers = items.length;
      }

      if (deletedRes.statusCode == 200) {
        final data = jsonDecode(deletedRes.body);
        final items = (data["items"] is List)
            ? data["items"] as List
            : <dynamic>[];
        deletedUsers = items.length;
      }

      final totalUsers = (newUsers - deletedUsers).clamp(0, 1 << 31).toInt();
      return _UsersStats(
        newUsers: newUsers,
        deletedUsers: deletedUsers,
        totalUsers: totalUsers,
      );
    } catch (e) {
      debugPrint("Errore _loadStats utenti: $e");
      return const _UsersStats(newUsers: 0, deletedUsers: 0, totalUsers: 0);
    }
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      futureStats = _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Utenti",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            IconButton(
              onPressed: _refresh,
              tooltip: "Aggiorna",
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          "Monitora nuove iscrizioni, utenti eliminati e totale utenti attivi.",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        FutureBuilder<_UsersStats>(
          future: futureStats,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final stats = snapshot.data!;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 260,
                  child: _statusCard(
                    label: "Nuovi iscritti",
                    count: stats.newUsers,
                    color: Colors.green.shade700,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NewUsersPage()),
                      );
                      _refresh();
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: _statusCard(
                    label: "Numero utenti",
                    count: stats.totalUsers,
                    color: Colors.blue.shade700,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NewUsersPage()),
                      );
                      _refresh();
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: _statusCard(
                    label: "Utenti eliminati",
                    count: stats.deletedUsers,
                    color: Colors.red.shade700,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DeletedUsersPage(),
                        ),
                      );
                      _refresh();
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("Nota"),
            subtitle: Text(
              "Le liste sono scrollabili e pensate per uso ufficio.",
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusCard({
    required String label,
    required int count,
    required Color color,
    VoidCallback? onTap,
  }) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
            ],
          ),
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }
}

class _UsersStats {
  final int newUsers;
  final int deletedUsers;
  final int totalUsers;

  const _UsersStats({
    required this.newUsers,
    required this.deletedUsers,
    required this.totalUsers,
  });
}
