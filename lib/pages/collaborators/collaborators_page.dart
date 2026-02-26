import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo/logiche/auth/auth_service.dart';

class CollaboratorsPage extends StatefulWidget {
  const CollaboratorsPage({super.key});

  @override
  State<CollaboratorsPage> createState() => _CollaboratorsPageState();
}

class _CollaboratorsPageState extends State<CollaboratorsPage> {
  late Future<List<_CollaboratorRow>> _futureRows;

  @override
  void initState() {
    super.initState();
    _futureRows = _loadRows();
  }

  Future<String?> _getToken() async {
    final token = await AuthService.instance.getIdToken();
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Nessun token disponibile");
      return null;
    }
    return token;
  }

  String _ownerLabel(Map<String, dynamic> item) {
    final email = (item["ownerEmail"] ?? item["email"] ?? "").toString().trim();
    if (email.isNotEmpty) return email;
    final uid = (item["userId"] ?? "").toString().trim();
    if (uid.isNotEmpty) return uid;
    return "Collaboratore sconosciuto";
  }

  DateTime? _parseCreatedAt(Map<String, dynamic> item) {
    final raw = (item["createdAt"] ?? item["updatedAt"] ?? "").toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  DateTime _startOfWeek(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    final shift = d.weekday - DateTime.monday;
    return d.subtract(Duration(days: shift));
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    return "$y-$m";
  }

  String _fmtEuroFromCents(int cents) {
    final sign = cents < 0 ? "-" : "";
    final abs = cents.abs();
    final euro = abs ~/ 100;
    final cent = abs % 100;
    return "$sign$euro,${cent.toString().padLeft(2, '0')}";
  }

  Future<int> _loadActivityMonthConfirmedCents({
    required String token,
    required String requestId,
    required String monthKey,
  }) async {
    final a = Uri.encodeComponent(requestId.trim());
    final m = Uri.encodeComponent(monthKey.trim());
    final url = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/purchase-activity-month?activityRequestId=$a&month=$m&limit=300",
    );

    try {
      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      if (res.statusCode == 401 || res.statusCode == 403) {
        return 0;
      }
      if (res.statusCode != 200) return 0;
      final data = jsonDecode(res.body);
      final items = (data is Map && data["items"] is List)
          ? data["items"] as List
          : <dynamic>[];
      var total = 0;
      for (final raw in items) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final status = (row["status"] ?? "").toString().trim().toLowerCase();
        if (status != "confirmed") continue;
        final cents = row["totalCents"];
        if (cents is num) {
          total += cents.toInt();
        } else {
          final parsed = int.tryParse(cents.toString());
          total += parsed ?? 0;
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<List<_CollaboratorRow>> _loadRows() async {
    final token = await _getToken();
    if (token == null) return <_CollaboratorRow>[];

    final approvedUrl = Uri.parse(
      "https://efs0gx9nm4.execute-api.eu-south-1.amazonaws.com/prod/activity-requests?status=approved",
    );
    final approvedRes = await http.get(
      approvedUrl,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (approvedRes.statusCode == 401 || approvedRes.statusCode == 403) {
      return <_CollaboratorRow>[];
    }
    if (approvedRes.statusCode != 200) {
      debugPrint("Errore approved activities: ${approvedRes.statusCode}");
      return <_CollaboratorRow>[];
    }

    final data = jsonDecode(approvedRes.body);
    final items = (data["items"] is List) ? data["items"] as List : <dynamic>[];
    final approved = items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final now = DateTime.now();
    final weekStart = _startOfWeek(now);
    final monthKey = _currentMonthKey();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in approved) {
      final key = _ownerLabel(item);
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }

    final rows = <_CollaboratorRow>[];
    for (final entry in grouped.entries) {
      final owner = entry.key;
      final activities = entry.value;
      final totalActivities = activities.length;
      final weeklyActivities = activities.where((it) {
        final dt = _parseCreatedAt(it);
        if (dt == null) return false;
        return !dt.isBefore(weekStart);
      }).length;

      var totalConfirmedCents = 0;
      for (final it in activities) {
        final requestId = (it["requestId"] ?? "").toString().trim();
        if (requestId.isEmpty) continue;
        totalConfirmedCents += await _loadActivityMonthConfirmedCents(
          token: token,
          requestId: requestId,
          monthKey: monthKey,
        );
      }

      rows.add(
        _CollaboratorRow(
          collaborator: owner,
          weeklyActivities: weeklyActivities,
          totalActivities: totalActivities,
          monthlyRevenueLabel: "€ ${_fmtEuroFromCents(totalConfirmedCents)}",
        ),
      );
    }

    rows.sort((a, b) => b.totalActivities.compareTo(a.totalActivities));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Collaboratori")),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueGrey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Scala provvigionale collaboratori",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text("Tier 1: 12-15 attività/mese • 10% • €20/attività"),
                Text("Tier 2: 16-19 attività/mese • 12,5% • €25/attività"),
                Text("Tier 3: 20+ attività/mese • 15% • €30/attività"),
                SizedBox(height: 8),
                Text("Soglia minima: 3 attività/settimana (altrimenti €10/attività)."),
                Text(
                  "Pagamento riconosciuto solo dopo la prima fattura pagata.",
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<_CollaboratorRow>>(
              future: _futureRows,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data ?? <_CollaboratorRow>[];
                if (rows.isEmpty) {
                  return const Center(
                    child: Text("Nessun collaboratore con attività affiliate."),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _futureRows = _loadRows());
                    await _futureRows;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final r = rows[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.collaborator,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Attività registrate settimana: ${r.weeklyActivities}",
                              ),
                              Text(
                                "Attività affiliate totali: ${r.totalActivities}",
                              ),
                              Text(
                                "Fatturato attività (mese corrente): ${r.monthlyRevenueLabel}",
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CollaboratorRow {
  const _CollaboratorRow({
    required this.collaborator,
    required this.weeklyActivities,
    required this.totalActivities,
    required this.monthlyRevenueLabel,
  });

  final String collaborator;
  final int weeklyActivities;
  final int totalActivities;
  final String monthlyRevenueLabel;
}
