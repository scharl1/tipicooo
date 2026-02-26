import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/utils/date_format_it.dart';

import 'activity_request_detail_page.dart';

class ActivityRequestsPage extends StatefulWidget {
  const ActivityRequestsPage({super.key});

  @override
  State<ActivityRequestsPage> createState() => _ActivityRequestsPageState();
}

class _ActivityRequestsPageState extends State<ActivityRequestsPage> {
  late Future<List<Map<String, dynamic>>> futureRequests;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    futureRequests = _loadRequests();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
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

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    try {
      final token = _getToken();
      final url = Uri.parse(
        "https://efs0gx9nm4.execute-api.eu-south-1.amazonaws.com/prod/activity-requests?status=pending",
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
        if (!mounted) return [];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Accesso revocato.")),
        );
        return [];
      }

      if (response.statusCode != 200) {
        debugPrint("Errore caricamento attività: ${response.body}");
        return [];
      }

      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data["items"] ?? []);
    } catch (e) {
      debugPrint("Errore _loadRequests: $e");
      return [];
    }
  }

  Future<void> _approve(String requestId) async {
    final token = _getToken();
    if (token == null || token.isEmpty) return;

    final url = Uri.parse(
      "https://efs0gx9nm4.execute-api.eu-south-1.amazonaws.com/prod/activity-request-approve",
    );

    await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: json.encode({"requestId": requestId}),
    );

    _refresh();
  }

  Future<void> _reject(String requestId) async {
    final token = _getToken();
    if (token == null || token.isEmpty) return;

    final url = Uri.parse(
      "https://efs0gx9nm4.execute-api.eu-south-1.amazonaws.com/prod/activity-request-reject",
    );

    await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: json.encode({"requestId": requestId}),
    );

    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      futureRequests = _loadRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Richieste attività"),
        actions: [
          IconButton(
            tooltip: "Aggiorna",
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Seleziona una richiesta per vedere i dettagli e decidere se approvarla.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: futureRequests,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = snapshot.data!;
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nessuna richiesta attività in attesa.",
                        style: TextStyle(fontSize: 16, color: Colors.black45),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final r = items[index];
                      final insegna = (r["insegna"] ?? "").toString();
                      final ragione = (r["ragione_sociale"] ?? "").toString();
                      final tipo = (r["tipo_attivita"] ?? "").toString();
                      final citta = (r["citta"] ?? "").toString();
                      final createdAt = (r["createdAt"] ?? "").toString();
                      final createdAtLabel = DateFormatIt.dateTime(createdAt);
                      final requestId = (r["requestId"] ?? "").toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          title: Text(insegna.isNotEmpty ? insegna : ragione),
                          subtitle: Text(
                            [
                              if (tipo.isNotEmpty) tipo,
                              if (citta.isNotEmpty) citta,
                              if (createdAtLabel.isNotEmpty) createdAtLabel,
                            ].join(" • "),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivityRequestDetailPage(
                                  data: r,
                                  onApprove: () => _approve(requestId),
                                  onReject: () => _reject(requestId),
                                ),
                              ),
                            );
                            _refresh();
                          },
                        ),
                      );
                    },
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
