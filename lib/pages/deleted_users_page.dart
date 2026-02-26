import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/utils/date_format_it.dart';

class DeletedUsersPage extends StatefulWidget {
  const DeletedUsersPage({super.key});

  @override
  State<DeletedUsersPage> createState() => _DeletedUsersPageState();
}

class _DeletedUsersPageState extends State<DeletedUsersPage> {
  late Future<List<Map<String, dynamic>>> futureItems;

  @override
  void initState() {
    super.initState();
    futureItems = _loadDeleted();
  }

  String? _getToken() {
    final token = OfficeAuth.token;
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Nessun token admin trovato in localStorage");
    }
    return token;
  }

  Future<List<Map<String, dynamic>>> _loadDeleted() async {
    try {
      final token = _getToken();
      final url = Uri.parse(
        "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/deleted-users-list",
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
        debugPrint("Errore caricamento utenti eliminati: ${response.body}");
        return [];
      }

      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data["items"] ?? []);
    } catch (e) {
      debugPrint("Errore _loadDeleted: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Utenti eliminati")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Qui trovi le email degli utenti che hanno cancellato o sono stati rimossi.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: futureItems,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = snapshot.data!;
                  final count = items.length;
                  if (count == 0) {
                    return const Center(
                      child: Text(
                        "Nessun utente eliminato negli ultimi 30 giorni.",
                        style: TextStyle(fontSize: 16, color: Colors.black45),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          "Totale: $count",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final email = (item["email"] ?? "").toString();
                            final reason = (item["reason"] ?? "").toString();
                            final note = (item["reasonNote"] ?? "").toString();
                            final deletedAt = (item["deletedAt"] ?? "").toString();
                            final deletedAtLabel = DateFormatIt.dateTime(deletedAt);
                            final by = (item["deletedBy"] ?? "").toString();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title:
                                    Text(email.isEmpty ? "Email non disponibile" : email),
                                subtitle: Text(
                                  [
                                    if (reason.isNotEmpty) reason,
                                    if (note.isNotEmpty) note,
                                    if (by.isNotEmpty) "da: $by",
                                    if (deletedAtLabel.isNotEmpty) deletedAtLabel,
                                  ].join(" • "),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
