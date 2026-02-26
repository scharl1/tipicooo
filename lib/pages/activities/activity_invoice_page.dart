import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/utils/date_format_it.dart';

class ActivityInvoicePage extends StatefulWidget {
  const ActivityInvoicePage({
    super.key,
    required this.activityRequestId,
    required this.activityName,
  });

  final String activityRequestId;
  final String activityName;

  @override
  State<ActivityInvoicePage> createState() => _ActivityInvoicePageState();
}

class _ActivityInvoicePageState extends State<ActivityInvoicePage> {
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  late String _monthKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthKey =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
    _load();
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

  String _fmtEuroFromCents(int cents) {
    final sign = cents < 0 ? "-" : "";
    final abs = cents.abs();
    final euro = abs ~/ 100;
    final cent = abs % 100;
    return "$sign$euro,${cent.toString().padLeft(2, '0')}";
  }

  int _commissionCents(Map<String, dynamic> it) {
    final direct = it["cashbackTotalCents"];
    if (direct is num) return direct.toInt();
    return 0;
  }

  String _pointOfSaleLabel(Map<String, dynamic> it) {
    final labels = <String>[
      (it["activityName"] ?? "").toString().trim(),
      (it["activityInsegna"] ?? "").toString().trim(),
      (it["handledActivityName"] ?? "").toString().trim(),
      (it["activityRequestId"] ?? "").toString().trim(),
    ];
    for (final l in labels) {
      if (l.isNotEmpty) return l;
    }
    return widget.activityName.trim().isEmpty
        ? "Punto vendita"
        : widget.activityName.trim();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
    });

    final token = _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Token non disponibile.";
      });
      return;
    }

    final q = <String, String>{
      "activityRequestId": widget.activityRequestId,
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

      if (res.statusCode == 401 || res.statusCode == 403) {
        OfficeAuth.clearToken();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = "Accesso revocato.";
        });
        return;
      }

      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = "Errore: ${res.statusCode}";
        });
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data["items"] is List)
          ? data["items"] as List
          : <dynamic>[];
      final rows = items.map((e) => Map<String, dynamic>.from(e)).toList();
      rows.sort((a, b) {
        final ak =
            ((a["handledAt"] ??
                    a["confirmedAt"] ??
                    a["rejectedAt"] ??
                    a["createdAt"] ??
                    "")
                .toString());
        final bk =
            ((b["handledAt"] ??
                    b["confirmedAt"] ??
                    b["rejectedAt"] ??
                    b["createdAt"] ??
                    "")
                .toString());
        return bk.compareTo(ak);
      });

      setState(() {
        _items.addAll(rows);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = "Errore di rete.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _items
        .where((it) => (it["status"] ?? "").toString().trim() == "confirmed")
        .toList();

    final grouped = <String, Map<String, int>>{};
    for (final it in confirmed) {
      final point = _pointOfSaleLabel(it);
      final totalCents = (it["totalCents"] is num)
          ? (it["totalCents"] as num).toInt()
          : 0;
      final commissionCents = _commissionCents(it);
      final slot = grouped.putIfAbsent(
        point,
        () => {"count": 0, "totalCents": 0, "commissionCents": 0},
      );
      slot["count"] = (slot["count"] ?? 0) + 1;
      slot["totalCents"] = (slot["totalCents"] ?? 0) + totalCents;
      slot["commissionCents"] =
          (slot["commissionCents"] ?? 0) + commissionCents;
    }

    final pointRows = grouped.entries.toList()
      ..sort((a, b) {
        final av = a.value["commissionCents"] ?? 0;
        final bv = b.value["commissionCents"] ?? 0;
        return bv.compareTo(av);
      });

    final totalOps = confirmed.length;
    final totalCommission = confirmed.fold<int>(
      0,
      (sum, it) => sum + _commissionCents(it),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Genera fattura"),
        actions: [
          IconButton(
            tooltip: "Aggiorna",
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.activityName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    await _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Numero totale operazioni: $totalOps",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Totale commissioni: € ${_fmtEuroFromCents(totalCommission)}",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Commissioni per punto vendita",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  children: [
                    if (pointRows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          "Nessuna operazione nel mese selezionato.",
                          style: TextStyle(color: Colors.black45),
                        ),
                      )
                    else
                      ...pointRows.map((entry) {
                        final label = entry.key;
                        final count = entry.value["count"] ?? 0;
                        final totalCents = entry.value["totalCents"] ?? 0;
                        final commissionCents =
                            entry.value["commissionCents"] ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(label),
                            subtitle: Text(
                              "Operazioni: $count • Totale: € ${_fmtEuroFromCents(totalCents)} • Commissioni: € ${_fmtEuroFromCents(commissionCents)}",
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    const Text(
                      "Elenco operazioni",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (confirmed.isEmpty)
                      const Text(
                        "Nessuna operazione confermata nel mese selezionato.",
                        style: TextStyle(color: Colors.black45),
                      )
                    else
                      ...confirmed.map((it) {
                        final requesterEmail = (it["requesterEmail"] ?? "")
                            .toString()
                            .trim();
                        final handledAt =
                            (it["handledAt"] ??
                                    it["confirmedAt"] ??
                                    it["createdAt"] ??
                                    "")
                                .toString();
                        final totalCents = (it["totalCents"] is num)
                            ? (it["totalCents"] as num).toInt()
                            : 0;
                        final commissionCents = _commissionCents(it);
                        final point = _pointOfSaleLabel(it);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const Icon(
                              Icons.receipt_long_outlined,
                              color: Colors.green,
                            ),
                            title: Text(
                              requesterEmail.isEmpty
                                  ? "Cliente: email non disponibile"
                                  : "Cliente: $requesterEmail",
                            ),
                            subtitle: Text(
                              [
                                "Punto vendita: $point",
                                "Importo: € ${_fmtEuroFromCents(totalCents)}",
                                "Commissione: € ${_fmtEuroFromCents(commissionCents)}",
                                if (handledAt.trim().isNotEmpty)
                                  "Data: ${DateFormatIt.dateTime(handledAt)}",
                              ].join(" • "),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
