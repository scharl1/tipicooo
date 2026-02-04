import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tipicooo/logiche/auth/auth_service.dart';

class AdminDeleteService {
  static const String baseUrl =
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod";

  static Future<bool> deleteUser(String userId) async {
    try {
      final idToken = await AuthService.instance.getIdToken();
      if (idToken == null) {
        throw Exception("ID Token non trovato");
      }

      // 🔵 STAMPA IL TOKEN CHE STAI USANDO
      print("🔵 TOKEN USATO PER DELETE:");
      print(idToken);

      final url = Uri.parse("$baseUrl/delete-user-admin");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "userId": userId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Errore deleteUserAdmin: $e");
      return false;
    }
  }
}