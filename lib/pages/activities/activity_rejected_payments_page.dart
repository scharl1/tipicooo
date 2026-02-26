// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/utils/date_format_it.dart';

class ActivityRejectedPaymentsPage extends StatefulWidget {
  const ActivityRejectedPaymentsPage({
    super.key,
    required this.activityRequestId,
    required this.activityEmail,
    required this.activityName,
  });

  final String activityRequestId;
  final String activityEmail;
  final String activityName;

  @override
  State<ActivityRejectedPaymentsPage> createState() => _ActivityRejectedPaymentsPageState();
}

class _ActivityRejectedPaymentsPageState extends State<ActivityRejectedPaymentsPage> {
  static const String _rejectedLatestAtKey = "officeRejectedLatestAt";
  static const String _rejectedLastSeenAtKey = "officeRejectedLastSeenAt";

  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  String? _nextAt;

  @override
  void initState() {
    super.initState();
    _markRejectedAsSeen();
    _loadFirst();
  }

  void _markRejectedAsSeen() {
    final latest = html.window.localStorage[_rejectedLatestAtKey];
    if (latest == null) return;
    final trimmed = latest.trim();
    if (trimmed.isEmpty) return;
    html.window.localStorage[_rejectedLastSeenAtKey] = trimmed;
  }

  String? _getToken() {
    final token = OfficeAuth.token;
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Nessun token admin trovato in localStorage");
    }
    return token;
  }

  String _fmtEuroFromCents(num value) {
    final cents = value.toInt();
    final sign = cents < 0 ? "-" : "";
    final abs = cents.abs();
    final euro = abs ~/ 100;
    final cent = abs % 100;
    return "$sign$euro,${cent.toString().padLeft(2, '0')}";
  }

  Future<void> _loadFirst() async {
    setState(() {
      _items.clear();
      _nextAt = null;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
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
      "limit": "50",
      if (_nextAt != null && _nextAt!.isNotEmpty) "startAt": _nextAt!,
    };

    final url = Uri.https(
      "dvyo7vax1g.execute-api.eu-south-1.amazonaws.com",
      "/prod/admin-purchase-activity-rejected",
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
        debugPrint("Errore admin-purchase-activity-rejected: ${res.body}");
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data["items"] is List) ? data["items"] as List : <dynamic>[];
      final nextAt = (data["nextAt"] ?? "").toString();

      setState(() {
        _items.addAll(items.map((e) => Map<String, dynamic>.from(e)));
        _nextAt = nextAt.isEmpty ? null : nextAt;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Errore di rete.";
      });
      debugPrint("Errore _loadMore rejected: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pagamenti rifiutati"),
        actions: [
          IconButton(
            tooltip: "Aggiorna",
            onPressed: _loadFirst,
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
            Text(
              "Email attività: ${widget.activityEmail.trim().isEmpty ? '-' : widget.activityEmail.trim()}",
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: _items.isEmpty && _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(
                          child: Text(
                            "Nessun pagamento rifiutato.",
                            style: TextStyle(color: Colors.black45),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _items.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _items.length) {
                              if (_nextAt == null) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      "Fine lista.",
                                      style: TextStyle(color: Colors.black45),
                                    ),
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: _loading
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton.icon(
                                          onPressed: _loadMore,
                                          icon: const Icon(Icons.expand_more),
                                          label: const Text("Carica altri"),
                                        ),
                                ),
                              );
                            }

                            final it = _items[index];
                            final requesterEmail = (it["requesterEmail"] ?? "").toString().trim();
                            final rejectedAt = (it["rejectedAt"] ?? "").toString();
                            final totalCents = (it["totalCents"] ?? 0) as num;
                            final rejectionCode = (it["rejectionCode"] ?? "").toString().trim();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: const Icon(Icons.block),
                                title: Text(
                                  requesterEmail.isEmpty ? "Cliente: email non disponibile" : "Cliente: $requesterEmail",
                                ),
                                subtitle: Text(
                                  [
                                    "Importo: € ${_fmtEuroFromCents(totalCents)}",
                                    if (rejectionCode.isNotEmpty) "Motivo: $rejectionCode",
                                    "Rifiutato: ${DateFormatIt.dateTime(rejectedAt)}",
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
