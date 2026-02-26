import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/pages/activities/activity_invoice_page.dart';
import 'package:tipicooo_office/utils/date_format_it.dart';
import 'package:url_launcher/url_launcher.dart';

class ActivityMovementsPage extends StatefulWidget {
  const ActivityMovementsPage({
    super.key,
    required this.activityRequestId,
    required this.activityName,
    required this.activityEmail,
  });

  final String activityRequestId;
  final String activityName;
  final String activityEmail;

  @override
  State<ActivityMovementsPage> createState() => _ActivityMovementsPageState();
}

class _ActivityMovementsPageState extends State<ActivityMovementsPage> {
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
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Nessun token admin trovato in localStorage");
    }
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

  String _fmtEuroFromCents(num value) {
    final cents = value.toInt();
    final sign = cents < 0 ? "-" : "";
    final abs = cents.abs();
    final euro = abs ~/ 100;
    final cent = abs % 100;
    return "$sign$euro,${cent.toString().padLeft(2, '0')}";
  }

  int _asCents(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
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
        debugPrint(
          "Errore purchase-activity-month: ${res.statusCode} ${res.body}",
        );
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
    } catch (e) {
      debugPrint("Errore _load movimenti: $e");
      setState(() {
        _loading = false;
        _error = "Errore di rete.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityEmail = widget.activityEmail.trim();
    final confirmed = _items
        .where((it) => (it["status"] ?? "").toString() == "confirmed")
        .toList();
    final confirmedTotalCents = confirmed.fold<int>(
      0,
      (sum, it) => sum + ((it["totalCents"] ?? 0) as num).toInt(),
    );
    final cashback10Cents = confirmed.fold<int>(
      0,
      (sum, it) => sum + _asCents(it["cashbackTotalCents"]),
    );
    final cashbackUser3Cents = confirmed.fold<int>(
      0,
      (sum, it) => sum + _asCents(it["userCashbackCents"]),
    );
    final cashbackReferrer3Cents = confirmed.fold<int>(
      0,
      (sum, it) => sum + _asCents(it["referrerCashbackCents"]),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Movimenti attività"),
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
            const SizedBox(height: 6),
            if (activityEmail.isEmpty)
              const Text(
                "Email attività: -",
                style: TextStyle(color: Colors.black54),
              )
            else
              InkWell(
                onTap: () async {
                  final uri = Uri.parse("mailto:$activityEmail");
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Text(
                  "Email attività: $activityEmail",
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.blue,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ActivityInvoicePage(
                      activityRequestId: widget.activityRequestId,
                      activityName: widget.activityName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text("Genera fattura"),
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
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Numero movimenti: ${confirmed.length}",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Totale generato: € ${_fmtEuroFromCents(confirmedTotalCents)}",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Cashback totale (10%): € ${_fmtEuroFromCents(cashback10Cents)}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Quota suggerimento (3%): € ${_fmtEuroFromCents(cashbackReferrer3Cents)}",
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Quota user (3%): € ${_fmtEuroFromCents(cashbackUser3Cents)}",
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : confirmed.isEmpty
                  ? const Center(
                      child: Text(
                        "Nessun pagamento accettato nel mese selezionato.",
                        style: TextStyle(color: Colors.black45),
                      ),
                    )
                  : ListView.builder(
                      itemCount: confirmed.length,
                      itemBuilder: (context, index) {
                        final it = confirmed[index];
                        final status = (it["status"] ?? "").toString();
                        final requesterEmail = (it["requesterEmail"] ?? "")
                            .toString()
                            .trim();
                        final totalCents = (it["totalCents"] ?? 0) as num;
                        final handledAt =
                            (it["handledAt"] ??
                                    it["confirmedAt"] ??
                                    it["rejectedAt"] ??
                                    "")
                                .toString();
                        final handledBy =
                            (it["handledByName"] ?? it["handledByEmail"] ?? "")
                                .toString()
                                .trim();
                        final rejectionCode = (it["rejectionCode"] ?? "")
                            .toString()
                            .trim();
                        final statusLabel = status == "confirmed"
                            ? "Confermato"
                            : status == "rejected"
                            ? "Rifiutato"
                            : status;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Icon(
                              status == "confirmed"
                                  ? Icons.check_circle
                                  : Icons.info_outline,
                              color: status == "confirmed"
                                  ? Colors.green
                                  : Colors.black54,
                            ),
                            title: Text(
                              requesterEmail.isEmpty
                                  ? "Cliente: email non disponibile"
                                  : "Cliente: $requesterEmail",
                            ),
                            subtitle: Text(
                              [
                                "Stato: $statusLabel",
                                "Importo: € ${_fmtEuroFromCents(totalCents)}",
                                if (handledBy.isNotEmpty)
                                  "Gestito da: $handledBy",
                                if (handledAt.trim().isNotEmpty)
                                  "Gestito: ${DateFormatIt.dateTime(handledAt)}",
                                if (status == "rejected" &&
                                    rejectionCode.isNotEmpty)
                                  "Motivo: $rejectionCode",
                              ].join(" • "),
                            ),
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
