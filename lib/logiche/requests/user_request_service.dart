import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tipicooo/logiche/auth/auth_service.dart';

class UserRequestService {
  static const String baseUrl =
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod";

  static Future<bool> sendAccessRequest() async {
    try {
      // Recuperiamo l'ID utente da Cognito
      final attributes = await AuthService.instance.getUserAttributes();
      final userId = attributes["sub"];

      if (userId == null) {
        throw Exception("User ID non trovato");
      }

      // Recuperiamo l'ID Token per l'Authorization header
      final idToken = await AuthService.instance.getIdToken();
      if (idToken == null) {
        throw Exception("ID Token non trovato");
      }

      final url = Uri.parse("$baseUrl/admin-request");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          // ⚠️ IMPORTANTE: niente "Bearer "
          "Authorization": idToken,
        },
        body: jsonEncode({
          "userId": userId,
        }),
      );

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("Errore invio richiesta: $e");
      return false;
    }
  }
}