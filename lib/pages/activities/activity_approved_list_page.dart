import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/pages/activities/activity_approved_detail_page.dart';
import 'package:tipicooo_office/pages/activities/activity_user_activities_page.dart';

class ActivityApprovedListPage extends StatefulWidget {
  const ActivityApprovedListPage({super.key});

  @override
  State<ActivityApprovedListPage> createState() =>
      _ActivityApprovedListPageState();
}

class _ActivityApprovedListPageState extends State<ActivityApprovedListPage> {
  late Future<List<Map<String, dynamic>>> futureItems;

  @override
  void initState() {
    super.initState();
    futureItems = _loadApproved();
  }

  String? _getToken() {
    final token = OfficeAuth.token;
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Nessun token admin trovato in localStorage");
    }
    return token;
  }

  Future<List<Map<String, dynamic>>> _loadApproved() async {
    try {
      final token = _getToken();
      final url = Uri.parse(
        "https://efs0gx9nm4.execute-api.eu-south-1.amazonaws.com/prod/activity-requests?status=approved",
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Accesso revocato.")));
        return [];
      }

      if (response.statusCode != 200) {
        debugPrint("Errore caricamento attività: ${response.body}");
        return [];
      }

      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data["items"] ?? []);
    } catch (e) {
      debugPrint("Errore _loadApproved: $e");
      return [];
    }
  }

  String _title(Map<String, dynamic> item) {
    final insegna = (item["insegna"] ?? "").toString();
    final ragione = (item["ragione_sociale"] ?? "").toString();
    if (insegna.isNotEmpty) return insegna;
    if (ragione.isNotEmpty) return ragione;
    return (item["requestId"] ?? "Attività").toString();
  }

  String _normalizeVat(String raw) {
    return raw
        .toUpperCase()
        .replaceAll(" ", "")
        .replaceAll(".", "")
        .replaceAll("-", "");
  }

  String _vatFrom(Map<String, dynamic> item) {
    final piva = (item["piva"] ?? item["partita_iva"] ?? "").toString().trim();
    return _normalizeVat(piva);
  }

  String _groupKey(Map<String, dynamic> item) {
    final vat = _vatFrom(item);
    if (vat.isNotEmpty) return "vat:$vat";
    final requestId = (item["requestId"] ?? "").toString().trim();
    return requestId.isEmpty ? "single:unknown" : "single:$requestId";
  }

  String _groupLabel(Map<String, dynamic> item) {
    final vat = _vatFrom(item);
    if (vat.isNotEmpty) return "P.IVA $vat";
    return "Attività senza P.IVA";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attività approvate")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Clicca una attività per aprire tutte le attività della stessa P.IVA.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: futureItems,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = snapshot.data!;
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nessuna attività approvata.",
                        style: TextStyle(fontSize: 16, color: Colors.black45),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final title = _title(item);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(title),
                          subtitle: Text(_groupLabel(item)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            final key = _groupKey(item);
                            final groupedItems = items
                                .where((it) => _groupKey(it) == key)
                                .toList();
                            if (groupedItems.length == 1) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ActivityApprovedDetailPage(
                                    activity: groupedItems.first,
                                  ),
                                ),
                              );
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ActivityUserActivitiesPage(
                                  userLabel: _groupLabel(item),
                                  activities: groupedItems,
                                ),
                              ),
                            );
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
