import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/pages/activities/activity_approved_detail_page.dart';

class ActivityUserActivitiesPage extends StatefulWidget {
  const ActivityUserActivitiesPage({
    super.key,
    required this.userLabel,
    required this.activities,
  });

  final String userLabel;
  final List<Map<String, dynamic>> activities;

  @override
  State<ActivityUserActivitiesPage> createState() =>
      _ActivityUserActivitiesPageState();
}

class _ActivityUserActivitiesPageState
    extends State<ActivityUserActivitiesPage> {
  bool _loadingTotals = false;
  String _monthKey = "";
  int _okCount = 0;
  int _okTotalCents = 0;
  int _koCount = 0;
  int _koTotalCents = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthKey =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
    _loadTotals();
  }

  String _title(Map<String, dynamic> item) {
    final insegna = (item["insegna"] ?? "").toString().trim();
    final ragione = (item["ragione_sociale"] ?? "").toString().trim();
    if (insegna.isNotEmpty) return insegna;
    if (ragione.isNotEmpty) return ragione;
    final requestId = (item["requestId"] ?? "").toString().trim();
    return requestId.isEmpty ? "Attività" : requestId;
  }

  String _type(Map<String, dynamic> item) {
    return (item["tipo_attivita"] ?? item["categoria"] ?? "").toString().trim();
  }

  String? _getToken() {
    final token = OfficeAuth.token;
    if (token == null || token.isEmpty) return null;
    return token;
  }

  List<String> _monthOptions({int monthsBack = 12}) {
    final now = DateTime.now();
    final out = <String>[];
    for (int i = 0; i <= monthsBack; i++) {
      final dt = DateTime(now.year, now.month - i, 1);
      out.add(
        "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}",
      );
    }
    return out;
  }

  bool _isRejectedOrEliminated(String status) {
    final s = status.trim().toLowerCase();
    return s == "rejected" ||
        s == "expired" ||
        s == "deleted" ||
        s == "cancelled" ||
        s == "canceled";
  }

  String _fmtEuroFromCents(int cents) {
    final sign = cents < 0 ? "-" : "";
    final abs = cents.abs();
    final euro = abs ~/ 100;
    final cent = abs % 100;
    return "$sign$euro,${cent.toString().padLeft(2, '0')}";
  }

  Future<void> _loadTotals() async {
    if (_loadingTotals) return;
    setState(() {
      _loadingTotals = true;
      _okCount = 0;
      _okTotalCents = 0;
      _koCount = 0;
      _koTotalCents = 0;
    });

    final token = _getToken();
    if (token == null) {
      if (!mounted) return;
      setState(() => _loadingTotals = false);
      return;
    }

    int okCount = 0;
    int okTotal = 0;
    int koCount = 0;
    int koTotal = 0;

    for (final activity in widget.activities) {
      final requestId = (activity["requestId"] ?? "").toString().trim();
      if (requestId.isEmpty) continue;

      final q = <String, String>{
        "activityRequestId": requestId,
        "month": _monthKey,
        "limit": "500",
      };
      final url = Uri.https(
        "dvyo7vax1g.execute-api.eu-south-1.amazonaws.com",
        "/prod/purchase-activity-month",
        q,
      );

      try {
        final res = await http.get(
          url,
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        );
        if (res.statusCode != 200) continue;

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (data["items"] is List)
            ? data["items"] as List
            : <dynamic>[];

        for (final raw in items) {
          if (raw is! Map) continue;
          final it = Map<String, dynamic>.from(raw);
          final status = (it["status"] ?? "").toString().trim().toLowerCase();
          final totalCents = (it["totalCents"] is num)
              ? (it["totalCents"] as num).toInt()
              : 0;

          if (status == "confirmed") {
            okCount += 1;
            okTotal += totalCents;
            continue;
          }
          if (_isRejectedOrEliminated(status)) {
            koCount += 1;
            koTotal += totalCents;
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (!mounted) return;
    setState(() {
      _okCount = okCount;
      _okTotalCents = okTotal;
      _koCount = koCount;
      _koTotalCents = koTotal;
      _loadingTotals = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attività raggruppate")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.userLabel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Attività trovate: ${widget.activities.length}",
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              "Mese contabile: tutti i mesi a 30 giorni, febbraio a 28/29; il giorno 31 confluisce nel mese successivo.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("Mese: "),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _monthKey,
                  items: _monthOptions()
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null || v == _monthKey) return;
                    setState(() => _monthKey = v);
                    await _loadTotals();
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: _loadingTotals
                  ? const Text("Calcolo riepilogo in corso...")
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Operazioni a buon fine: $_okCount • Totale € ${_fmtEuroFromCents(_okTotalCents)}",
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Operazioni rifiutate/eliminate: $_koCount • Totale € ${_fmtEuroFromCents(_koTotalCents)}",
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: widget.activities.length,
                itemBuilder: (context, index) {
                  final item = widget.activities[index];
                  final title = _title(item);
                  final type = _type(item);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(title),
                      subtitle: type.isEmpty ? null : Text(type),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ActivityApprovedDetailPage(activity: item),
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
      ),
    );
  }
}
