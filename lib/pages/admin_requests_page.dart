import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/utils/date_format_it.dart';

class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({super.key});

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  late Future<List<Map<String, dynamic>>> futureRequests;
  late Future<_StatusCounts> futureStats;
  late Future<List<Map<String, dynamic>>> futureAdmins;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    futureRequests = _loadRequests();
    futureStats = _loadStats();
    futureAdmins = _loadAdmins();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _refreshAll();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ⭐ Recupera token da localStorage
  String? _getToken() {
    final token = OfficeAuth.token;
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Nessun token admin trovato in localStorage");
    }
    return token;
  }

  // ⭐ CARICA RICHIESTE
  Future<List<Map<String, dynamic>>> _loadRequests() async {
    try {
      final token = _getToken();
      final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

      final url = Uri.parse(
        "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-list-requests?_=$cacheBuster",
      );

      final response = await http.get(
        url,
        headers: {
          "Authorization": token == null ? "" : "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        // Accesso revocato: pulisci token e blocca accesso
        OfficeAuth.clearToken();
        if (!mounted) return [];
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Accesso revocato.")));
        return [];
      }

      if (response.statusCode != 200) {
        debugPrint("Errore caricamento richieste: ${response.body}");
        return [];
      }

      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data["items"]);
    } catch (e) {
      debugPrint("Errore _loadRequests: $e");
      return [];
    }
  }

  // ⭐ CARICA CONTATORI
  Future<_StatusCounts> _loadStats() async {
    try {
      final token = _getToken();
      final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

      final url = Uri.parse(
        "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-requests-stats?_=$cacheBuster",
      );

      final response = await http.get(
        url,
        headers: {
          "Authorization": token == null ? "" : "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        OfficeAuth.clearToken();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Accesso revocato.")));
        }
        return const _StatusCounts(
          approved: 0,
          pending: 0,
          rejected: 0,
          activeAdmins: 0,
        );
      }

      if (response.statusCode != 200) {
        debugPrint("Errore caricamento stats: ${response.body}");
        return const _StatusCounts(
          approved: 0,
          pending: 0,
          rejected: 0,
          activeAdmins: 0,
        );
      }

      final data = json.decode(response.body);
      final approved = (data["approved"] ?? 0) as int;
      final pending = (data["pending"] ?? 0) as int;
      final rejected = (data["rejected"] ?? 0) as int;
      final activeAdmins = await _loadAdminsCount();

      return _StatusCounts(
        approved: approved,
        pending: pending,
        rejected: rejected,
        activeAdmins: activeAdmins,
      );
    } catch (e) {
      debugPrint("Errore _loadStats: $e");
      return const _StatusCounts(
        approved: 0,
        pending: 0,
        rejected: 0,
        activeAdmins: 0,
      );
    }
  }

  Future<int> _loadAdminsCount() async {
    try {
      final token = _getToken();
      final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      final url = Uri.parse(
        "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-admins-count?_=$cacheBuster",
      );

      final response = await http.get(
        url,
        headers: {
          "Authorization": token == null ? "" : "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        OfficeAuth.clearToken();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Accesso revocato.")));
        }
        return 0;
      }

      if (response.statusCode != 200) {
        debugPrint("Errore caricamento admin autorizzati: ${response.body}");
        return 0;
      }

      final data = json.decode(response.body);
      return (data["admins"] ?? 0) as int;
    } catch (e) {
      debugPrint("Errore _loadAdminsCount: $e");
      return 0;
    }
  }

  void _refreshAll() {
    if (!mounted) return;
    setState(() {
      futureRequests = _loadRequests();
      futureStats = _loadStats();
      futureAdmins = _loadAdmins();
    });
  }

  // ⭐ CARICA ADMIN AUTORIZZATI
  Future<List<Map<String, dynamic>>> _loadAdmins() async {
    try {
      final token = _getToken();

      final url = Uri.parse(
        "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-admins-list",
      );

      final response = await http.get(
        url,
        headers: {
          "Authorization": token == null ? "" : "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        OfficeAuth.clearToken();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Accesso revocato.")));
        }
        return [];
      }

      if (response.statusCode != 200) {
        debugPrint("Errore caricamento admin: ${response.body}");
        return [];
      }

      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data["items"] ?? []);
    } catch (e) {
      debugPrint("Errore _loadAdmins: $e");
      return [];
    }
  }

  Future<void> _removeAdmin(String userId) async {
    final token = _getToken();
    if (token == null || token.isEmpty) return;

    final url = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-remove-admin",
    );

    await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: json.encode({"userId": userId}),
    );

    // Pulizia richieste in DB per evitare stato "in attesa" residuale
    final cleanupUrl = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-delete-user-requests",
    );
    await http.post(
      cleanupUrl,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: json.encode({"userId": userId}),
    );

    _refreshAll();
  }

  // ⭐ APPROVA RICHIESTA
  Future<void> _approve(String requestId, String userId) async {
    final token = _getToken();

    final url = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-approve",
    );

    await http.post(
      url,
      headers: {
        "Authorization": token == null ? "" : "Bearer $token",
        "Content-Type": "application/json",
      },
      body: json.encode({"requestId": requestId, "userId": userId}),
    );

    _refreshAll();
  }

  // ⭐ RIFIUTA RICHIESTA (CORRETTO)
  Future<void> _reject(String requestId, String userId) async {
    final token = _getToken();

    final url = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin_reject",
    );

    await http.post(
      url,
      headers: {
        "Authorization": token == null ? "" : "Bearer $token",
        "Content-Type": "application/json",
      },
      body: json.encode({"requestId": requestId, "userId": userId}),
    );

    _refreshAll();
  }

  // ⭐ ELIMINA TUTTE LE RICHIESTE DI UN UTENTE
  Future<void> _deleteAllUserRequests(String userId) async {
    final token = _getToken();

    final url = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-delete-user-requests",
    );

    await http.post(
      url,
      headers: {
        "Authorization": token == null ? "" : "Bearer $token",
        "Content-Type": "application/json",
      },
      body: json.encode({"userId": userId}),
    );

    setState(() {
      futureRequests = _loadRequests();
      futureStats = _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Richieste di abilitazione",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Gestisci le richieste inviate dagli utenti dell’app mobile.",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          FutureBuilder<_StatusCounts>(
            future: futureStats,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final counts = snapshot.data!;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: _statusCard(
                      label: "Approvate",
                      count: counts.approved,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _statusCard(
                      label: "In attesa",
                      count: counts.pending,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _statusCard(
                      label: "Admin autorizzati",
                      count: counts.activeAdmins,
                      color: Colors.blue,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "Admin autorizzati",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: futureAdmins,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final admins = snapshot.data!;
              if (admins.isEmpty) {
                return const Text(
                  "Nessun admin presente.",
                  style: TextStyle(fontSize: 14, color: Colors.black45),
                );
              }

              const ownerEmail = "carlo.mertolini@gmail.com";

              final visibleAdmins = admins.where((a) {
                final email = (a["email"] ?? "")
                    .toString()
                    .toLowerCase()
                    .trim();
                return email.isEmpty || email != ownerEmail;
              }).toList();

              if (visibleAdmins.isEmpty) {
                return const Text(
                  "Nessun admin disponibile.",
                  style: TextStyle(fontSize: 14, color: Colors.black45),
                );
              }

              return Column(
                children: visibleAdmins.map((a) {
                  final email = (a["email"] ?? "").toString();
                  final given = (a["givenName"] ?? "").toString();
                  final family = (a["familyName"] ?? "").toString();
                  final name = ("$given $family").trim();
                  final userId = (a["userId"] ?? "").toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(name.isEmpty ? email : name),
                      subtitle: Text(email.isEmpty ? userId : email),
                      trailing: TextButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Rimuovi admin"),
                              content: const Text(
                                "Sei sicuro di voler rimuovere questo admin?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Annulla"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Rimuovi"),
                                ),
                              ],
                            ),
                          );

                          if (ok == true) {
                            await _removeAdmin(userId);
                          }
                        },
                        child: const Text("Rimuovi"),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: futureRequests,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requests = snapshot.data!;

                if (requests.isEmpty) {
                  return const Center(
                    child: Text(
                      "Nessuna richiesta presente.",
                      style: TextStyle(fontSize: 16, color: Colors.black45),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final r = requests[index];
                    return requestCard(
                      name: r["name"],
                      email: r["email"],
                      date: DateFormatIt.dateTime(
                        (r["createdAt"] ?? "").toString(),
                      ),
                      onApprove: () => _approve(r["requestId"], r["userId"]),
                      onReject: () => _reject(r["requestId"], r["userId"]),
                      onDeleteAll: () => _deleteAllUserRequests(r["userId"]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget requestCard({
    required String name,
    required String email,
    required String date,
    required VoidCallback onApprove,
    required VoidCallback onReject,
    required VoidCallback onDeleteAll,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              email,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              "Richiesta: $date",
              style: const TextStyle(fontSize: 14, color: Colors.black45),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                approveButton(onApprove),
                const SizedBox(width: 12),
                rejectButton(onReject),
                const SizedBox(width: 12),
                deleteAllButton(onDeleteAll),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget approveButton(VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.check),
      label: const Text("Approva"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  Widget rejectButton(VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.close),
      label: const Text("Rifiuta"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  Widget deleteAllButton(VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.delete_outline),
      label: const Text("Elimina tutte"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.black38,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }
}

class _StatusCounts {
  final int approved;
  final int pending;
  final int rejected;
  final int activeAdmins;

  const _StatusCounts({
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.activeAdmins,
  });
}
