import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      "https://si7o1objgf.execute-api.eu-central-1.amazonaws.com/dev";

  // ⭐ Recupera il token salvato da main.dart
  static String? _getToken() {
    final token = html.window.localStorage["adminToken"];
    if (token == null || token.isEmpty) {
      print("⚠️ Nessun token admin trovato in localStorage");
    }
    return token;
  }

  // ⭐ GET — Recupera tutte le richieste
  static Future<List<dynamic>> getRequests() async {
    final token = _getToken();

    final response = await http.get(
      Uri.parse("$baseUrl/admin/requests"),
      headers: {
        "Authorization": token ?? "",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception("Errore caricamento richieste: ${response.statusCode}");
  }

  // ⭐ POST — Approva una richiesta
  static Future<bool> approveRequest(String requestId) async {
    final token = _getToken();

    final response = await http.post(
      Uri.parse("$baseUrl/admin/requests/$requestId/approve"),
      headers: {
        "Authorization": token ?? "",
      },
    );

    return response.statusCode == 200;
  }

  // ⭐ POST — Rifiuta una richiesta
  static Future<bool> rejectRequest(String requestId) async {
    final token = _getToken();

    final response = await http.post(
      Uri.parse("$baseUrl/admin/requests/$requestId/reject"),
      headers: {
        "Authorization": token ?? "",
      },
    );

    return response.statusCode == 200;
  }
}