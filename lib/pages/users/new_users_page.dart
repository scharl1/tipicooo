// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/utils/date_format_it.dart';

class NewUsersPage extends StatefulWidget {
  const NewUsersPage({super.key});

  @override
  State<NewUsersPage> createState() => _NewUsersPageState();
}

class _NewUsersPageState extends State<NewUsersPage> {
  static const String _latestSkKey = "officeNewUsersLatestSk";
  static const String _lastSeenSkKey = "officeNewUsersLastSeenSk";

  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _nextSk;
  String? _error;

  @override
  void initState() {
    super.initState();
    _markAsSeen();
    _loadFirst();
  }

  String? _getToken() {
    final token = OfficeAuth.token;
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Nessun token admin trovato in localStorage");
    }
    return token;
  }

  void _markAsSeen() {
    final latest = html.window.localStorage[_latestSkKey];
    if (latest == null) return;
    final trimmed = latest.trim();
    if (trimmed.isEmpty) return;
    html.window.localStorage[_lastSeenSkKey] = trimmed;
  }

  Future<void> _loadFirst() async {
    setState(() {
      _items.clear();
      _nextSk = null;
      _error = null;
    });
    await _loadAll();
  }

  Future<void> _loadAll() async {
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

    try {
      String? cursor = _nextSk;
      final loaded = <Map<String, dynamic>>[];
      const int maxPages = 200;
      int page = 0;

      while (page < maxPages) {
        page++;
        final q = <String, String>{
          "limit": "50",
          if (cursor != null && cursor.isNotEmpty) "startSk": cursor,
          "_": DateTime.now().millisecondsSinceEpoch.toString(),
        };

        final url = Uri.https(
          "dvyo7vax1g.execute-api.eu-south-1.amazonaws.com",
          "/prod/admin-new-users-list",
          q,
        );

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
          debugPrint("Errore admin-new-users-list: ${res.body}");
          return;
        }

        final data = jsonDecode(res.body);
        final items = (data["items"] is List)
            ? data["items"] as List
            : <dynamic>[];
        loaded.addAll(items.map((e) => Map<String, dynamic>.from(e)));

        final nextSk = (data["nextSk"] ?? "").toString();
        if (nextSk.isEmpty) {
          cursor = null;
          break;
        }
        cursor = nextSk;
      }

      setState(() {
        _items
          ..clear()
          ..addAll(loaded);
        _nextSk = cursor;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Errore di rete.";
      });
      debugPrint("Errore _loadMore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nuovi iscritti"),
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
            const Text(
              "Email degli utenti che si sono registrati.",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: _items.isEmpty && _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(
                      child: Text(
                        "Nessun utente presente.",
                        style: TextStyle(color: Colors.black45),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          if (_nextSk == null) {
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
                                      onPressed: _loadAll,
                                      icon: const Icon(Icons.expand_more),
                                      label: const Text("Carica altri"),
                                    ),
                            ),
                          );
                        }

                        final item = _items[index];
                        final email = (item["email"] ?? "").toString();
                        final createdAt = (item["createdAt"] ?? "").toString();
                        final createdAtLabel = DateFormatIt.dateTime(createdAt);
                        final userId = (item["userId"] ?? "").toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(
                              email.isEmpty ? "Email non disponibile" : email,
                            ),
                            subtitle: Text(
                              [
                                if (createdAtLabel.isNotEmpty) createdAtLabel,
                                if (userId.isNotEmpty) userId,
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
