import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/utils/date_format_it.dart';

class ActivityDriversPage extends StatefulWidget {
  const ActivityDriversPage({super.key});

  @override
  State<ActivityDriversPage> createState() => _ActivityDriversPageState();
}

class _ActivityDriversPageState extends State<ActivityDriversPage> {
  late Future<List<Map<String, dynamic>>> _futureItems;

  @override
  void initState() {
    super.initState();
    _futureItems = _loadItems();
  }

  String? _getToken() {
    final token = OfficeAuth.token;
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Nessun token admin trovato in localStorage");
    }
    return token;
  }

  bool _asBool(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final raw = item[key];
      if (raw is bool) return raw;
      final value = (raw ?? "").toString().trim().toLowerCase();
      if (value == "true" || value == "1" || value == "si" || value == "sì") {
        return true;
      }
      if (value == "false" || value == "0" || value == "no") {
        return false;
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> _loadItems() async {
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
        debugPrint("Errore caricamento attività autisti: ${response.body}");
        return [];
      }

      final data = jsonDecode(response.body);
      final items = List<Map<String, dynamic>>.from(data["items"] ?? const []);

      final filtered = items.where((it) {
        return _hasAnyDriverFeature(it);
      }).toList();

      filtered.sort((a, b) {
        final ad = (a["createdAt"] ?? "").toString();
        final bd = (b["createdAt"] ?? "").toString();
        return bd.compareTo(ad);
      });

      return filtered;
    } catch (e) {
      debugPrint("Errore _loadItems (autisti): $e");
      return [];
    }
  }

  bool _hasAnyDriverFeature(Map<String, dynamic> item) {
    final hasPrivateParking = _asBool(item, const [
      "has_private_parking",
      "hasPrivateParking",
    ]);
    final hasBusinessLunch = _asBool(item, const [
      "has_business_lunch",
      "hasBusinessLunch",
    ]);
    final hasShowers = _asBool(item, const [
      "has_showers",
      "hasShowers",
    ]);
    final truckAllowed = _asBool(item, const [
      "truck_parking_allowed",
      "truckParkingAllowed",
    ]);
    final guestOptions = _guestParkingOptions(item);
    return hasPrivateParking ||
        hasBusinessLunch ||
        hasShowers ||
        truckAllowed ||
        guestOptions.isNotEmpty;
  }

  String _title(Map<String, dynamic> item) {
    final insegna = (item["insegna"] ?? "").toString().trim();
    final ragione = (item["ragione_sociale"] ?? "").toString().trim();
    if (insegna.isNotEmpty) return insegna;
    if (ragione.isNotEmpty) return ragione;
    return (item["requestId"] ?? "Attività").toString();
  }

  String _cityLine(Map<String, dynamic> item) {
    final citta = (item["citta"] ?? "").toString().trim();
    final provincia = (item["provincia"] ?? "").toString().trim();
    final paese = (item["paese"] ?? "").toString().trim();
    return [if (citta.isNotEmpty) citta, if (provincia.isNotEmpty) provincia, if (paese.isNotEmpty) paese].join(", ");
  }

  String _lunchLine(Map<String, dynamic> item) {
    final raw = item["business_lunch_slots"] ?? item["businessLunchSlots"];
    if (raw is List) {
      final values = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (values.isNotEmpty) return values.join(" • ");
    }
    return "Disponibile";
  }

  String _showersLine(Map<String, dynamic> item) {
    final hasShowers = _asBool(item, const [
      "has_showers",
      "hasShowers",
    ]);
    return hasShowers ? "Sì" : "No";
  }

  List<String> _guestParkingOptions(Map<String, dynamic> item) {
    final raw = item["guest_parking_options"] ?? item["guestParkingOptions"];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _guestParkingLine(Map<String, dynamic> item) {
    final options = _guestParkingOptions(item);
    final other = (item["guest_parking_other_text"] ??
            item["guestParkingOtherText"] ??
            "")
        .toString()
        .trim();
    if (options.isEmpty && other.isEmpty) return "N/D";
    final parts = <String>[...options, if (other.isNotEmpty) other];
    return parts.join(" • ");
  }

  String _truckLine(Map<String, dynamic> item) {
    final allowed = _asBool(item, const [
      "truck_parking_allowed",
      "truckParkingAllowed",
    ]);
    if (!allowed) return "No";
    final capacity = (item["truck_parking_capacity"] ?? item["truckParkingCapacity"] ?? "")
        .toString()
        .trim();
    if (capacity.isEmpty) return "Sì";
    return "Sì ($capacity)";
  }

  void _refresh() {
    setState(() {
      _futureItems = _loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attività per autisti"),
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
              "Elenco attività con caratteristiche utili agli autisti.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _futureItems,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nessuna attività trovata con i requisiti richiesti.",
                        style: TextStyle(fontSize: 16, color: Colors.black45),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final it = items[index];
                      final type = (it["tipo_attivita"] ?? "").toString().trim();
                      final city = _cityLine(it);
                      final createdAt = DateFormatIt.dateTime(
                        (it["createdAt"] ?? "").toString(),
                      );

                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          title: Text(
                            _title(it),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (type.isNotEmpty) Text("Tipo: $type"),
                                if (city.isNotEmpty) Text("Località: $city"),
                                Text(
                                  "Parcheggio privato: ${_asBool(it, const ["has_private_parking", "hasPrivateParking"]) ? "Sì" : "No"}",
                                ),
                                Text("Pranzi di lavoro: ${_lunchLine(it)}"),
                                Text("Parcheggio autoarticolati: ${_truckLine(it)}"),
                                Text("Parcheggio ospiti: ${_guestParkingLine(it)}"),
                                Text("Docce: ${_showersLine(it)}"),
                                if (createdAt.isNotEmpty) Text("Registrata: $createdAt"),
                              ],
                            ),
                          ),
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
