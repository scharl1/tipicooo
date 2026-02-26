import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';

enum _PeriodFilter { weekCurrent, monthCurrent, monthPrevious }

class CollaboratorsPage extends StatefulWidget {
  const CollaboratorsPage({super.key});

  @override
  State<CollaboratorsPage> createState() => _CollaboratorsPageState();
}

class _CollaboratorsPageState extends State<CollaboratorsPage> {
  late Future<List<Map<String, dynamic>>> _futurePendingRequests;
  int _lastPendingCount = 0;
  late Future<List<_CollaboratorRow>> _futureRows;
  _PeriodFilter _periodFilter = _PeriodFilter.monthCurrent;

  @override
  void initState() {
    super.initState();
    _futureRows = _loadRows();
    _futurePendingRequests = _loadPendingRequests();
  }

  String? _getToken() {
    final token = OfficeAuth.token;
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Nessun token admin trovato in localStorage");
      return null;
    }
    return token;
  }

  Future<List<Map<String, dynamic>>> _loadPendingRequests() async {
    final token = _getToken();
    if (token == null) return <Map<String, dynamic>>[];

    try {
      final url = Uri.parse(
        "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/collaborator-requests?status=pending",
      );
      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (res.statusCode == 401 || res.statusCode == 403) {
        debugPrint(
          "Collaborator requests non accessibile (${res.statusCode}) senza invalidare sessione office.",
        );
        return <Map<String, dynamic>>[];
      }
      if (res.statusCode == 404) {
        return <Map<String, dynamic>>[];
      }
      if (res.statusCode != 200) return <Map<String, dynamic>>[];

      final data = jsonDecode(res.body);
      final items = (data is Map && data["items"] is List)
          ? data["items"] as List
          : <dynamic>[];
      final list = items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (mounted && list.length > _lastPendingCount && _lastPendingCount > 0) {
        final delta = list.length - _lastPendingCount;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              delta == 1
                  ? "Nuova richiesta collaboratore ricevuta."
                  : "Nuove richieste collaboratore: $delta.",
            ),
          ),
        );
      }
      _lastPendingCount = list.length;
      return list;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _approveRequest(Map<String, dynamic> req) async {
    final token = _getToken();
    if (token == null) return;
    final requestId = (req["requestId"] ?? "").toString().trim();
    final userId = (req["userId"] ?? "").toString().trim();
    if (requestId.isEmpty && userId.isEmpty) return;

    final res = await http.post(
      Uri.parse(
        "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/collaborator-approve",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"requestId": requestId, "userId": userId}),
    );

    if (!mounted) return;
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Richiesta collaboratore approvata.")),
      );
      setState(() {
        _futurePendingRequests = _loadPendingRequests();
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Errore approvazione (${res.statusCode}).")),
    );
  }

  Future<void> _rejectRequest(Map<String, dynamic> req) async {
    final token = _getToken();
    if (token == null) return;
    final requestId = (req["requestId"] ?? "").toString().trim();
    final userId = (req["userId"] ?? "").toString().trim();
    if (requestId.isEmpty && userId.isEmpty) return;

    final res = await http.post(
      Uri.parse(
        "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/collaborator-reject",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"requestId": requestId, "userId": userId}),
    );

    if (!mounted) return;
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Richiesta collaboratore rifiutata.")),
      );
      setState(() {
        _futurePendingRequests = _loadPendingRequests();
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Errore rifiuto (${res.statusCode}).")),
    );
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

  String _monthKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return "$y-$m";
  }

  String _currentMonthKey() => _monthKey(DateTime.now());

  String _previousMonthKey() {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);
    return _monthKey(prev);
  }

  String _fmtEuroFromCents(int cents) {
    final sign = cents < 0 ? "-" : "";
    final abs = cents.abs();
    final euro = abs ~/ 100;
    final cent = abs % 100;
    return "$sign$euro,${cent.toString().padLeft(2, '0')}";
  }

  String _periodLabel() {
    switch (_periodFilter) {
      case _PeriodFilter.weekCurrent:
        return "settimana corrente";
      case _PeriodFilter.monthCurrent:
        return "mese corrente";
      case _PeriodFilter.monthPrevious:
        return "mese precedente";
    }
  }

  String _tierLabel(int periodActivities) {
    if (periodActivities >= 20) return "Tier 3";
    if (periodActivities >= 16) return "Tier 2";
    if (periodActivities >= 12) return "Tier 1";
    return "Base";
  }

  Color _tierColor(int periodActivities) {
    if (periodActivities >= 20) return const Color(0xFF1D9B4E);
    if (periodActivities >= 16) return const Color(0xFF0B5ED7);
    if (periodActivities >= 12) return const Color(0xFFF08C00);
    return const Color(0xFF7A7A7A);
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
        debugPrint(
          "Purchase activity month non accessibile (${res.statusCode}) senza invalidare sessione office.",
        );
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
    final token = _getToken();
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
      debugPrint(
        "Approved activities non accessibili (${approvedRes.statusCode}) senza invalidare sessione office.",
      );
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
    final weekEndExclusive = weekStart.add(const Duration(days: 7));
    final currentMonth = _currentMonthKey();
    final previousMonth = _previousMonthKey();

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
        return !dt.isBefore(weekStart) && dt.isBefore(weekEndExclusive);
      }).length;

      final monthCurrentActivities = activities.where((it) {
        final dt = _parseCreatedAt(it);
        if (dt == null) return false;
        return _monthKey(dt) == currentMonth;
      }).length;

      final monthPreviousActivities = activities.where((it) {
        final dt = _parseCreatedAt(it);
        if (dt == null) return false;
        return _monthKey(dt) == previousMonth;
      }).length;

      int periodActivities;
      String revenueMonthKey;
      switch (_periodFilter) {
        case _PeriodFilter.weekCurrent:
          periodActivities = weeklyActivities;
          revenueMonthKey = currentMonth;
          break;
        case _PeriodFilter.monthCurrent:
          periodActivities = monthCurrentActivities;
          revenueMonthKey = currentMonth;
          break;
        case _PeriodFilter.monthPrevious:
          periodActivities = monthPreviousActivities;
          revenueMonthKey = previousMonth;
          break;
      }

      var totalConfirmedCents = 0;
      for (final it in activities) {
        final requestId = (it["requestId"] ?? "").toString().trim();
        if (requestId.isEmpty) continue;
        totalConfirmedCents += await _loadActivityMonthConfirmedCents(
          token: token,
          requestId: requestId,
          monthKey: revenueMonthKey,
        );
      }

      rows.add(
        _CollaboratorRow(
          collaborator: owner,
          weeklyActivities: weeklyActivities,
          totalActivities: totalActivities,
          periodActivities: periodActivities,
          monthlyRevenueLabel: "€ ${_fmtEuroFromCents(totalConfirmedCents)}",
          tierLabel: _tierLabel(periodActivities),
          tierColor: _tierColor(periodActivities),
        ),
      );
    }

    rows.sort((a, b) => b.periodActivities.compareTo(a.periodActivities));
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text("Periodo:"),
                const SizedBox(width: 10),
                DropdownButton<_PeriodFilter>(
                  value: _periodFilter,
                  items: const [
                    DropdownMenuItem(
                      value: _PeriodFilter.weekCurrent,
                      child: Text("Settimana corrente"),
                    ),
                    DropdownMenuItem(
                      value: _PeriodFilter.monthCurrent,
                      child: Text("Mese corrente"),
                    ),
                    DropdownMenuItem(
                      value: _PeriodFilter.monthPrevious,
                      child: Text("Mese precedente"),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _periodFilter = v;
                      _futureRows = _loadRows();
                    });
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _futurePendingRequests,
              builder: (context, snapshot) {
                final pending = snapshot.data ?? const <Map<String, dynamic>>[];
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Richieste collaboratore in attesa: ${pending.length}",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (pending.isEmpty)
                        const Text("Nessuna richiesta in attesa.")
                      else
                        Column(
                          children: pending.take(3).map((r) {
                            final name = (r["name"] ?? r["email"] ?? r["userId"] ?? "-")
                                .toString();
                            final email = (r["email"] ?? "-").toString();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F9F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text(email, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _approveRequest(r),
                                    child: const Text("Approva"),
                                  ),
                                  TextButton(
                                    onPressed: () => _rejectRequest(r),
                                    child: const Text("Rifiuta"),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                );
              },
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
                    setState(() {
                      _futureRows = _loadRows();
                      _futurePendingRequests = _loadPendingRequests();
                    });
                    await _futureRows;
                    await _futurePendingRequests;
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.collaborator,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: r.tierColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: r.tierColor),
                                    ),
                                    child: Text(
                                      r.tierLabel,
                                      style: TextStyle(
                                        color: r.tierColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text("Attività registrate settimana: ${r.weeklyActivities}"),
                              Text("Attività affiliate totali: ${r.totalActivities}"),
                              Text("Attività nel periodo (${_periodLabel()}): ${r.periodActivities}"),
                              Text(
                                "Fatturato attività (${_periodLabel()}): ${r.monthlyRevenueLabel}",
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
    required this.periodActivities,
    required this.monthlyRevenueLabel,
    required this.tierLabel,
    required this.tierColor,
  });

  final String collaborator;
  final int weeklyActivities;
  final int totalActivities;
  final int periodActivities;
  final String monthlyRevenueLabel;
  final String tierLabel;
  final Color tierColor;
}
