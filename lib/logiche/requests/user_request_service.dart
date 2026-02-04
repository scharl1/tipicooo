import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

class UserRequestService {
  static const String baseUrl =
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod";

  // ⭐ INVIO RICHIESTA ACCESSO
  static Future<bool> sendAccessRequest() async {
    try {
      // Recuperiamo l'ID utente da Cognito
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final attributes = await Amplify.Auth.fetchUserAttributes();
      final userId = attributes
          .firstWhere((a) => a.userAttributeKey.key == "sub")
          .value;

      final url = Uri.parse("$baseUrl/admin-request");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
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

  // ⭐ RECUPERO STATO UTENTE (abilitato / richiesta inviata)
  static Future<Map<String, dynamic>> getUserStatus() async {
    try {
      // Recuperiamo l'ID Token Cognito VERO
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final url = Uri.parse("$baseUrl/admin-request/status");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": idToken,
        },
      );

      print("STATUS (getUserStatus): ${response.statusCode}");
      print("BODY (getUserStatus): ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      if (response.statusCode == 404) {
        return {
          "enabled": false,
          "requested": false,
        };
      }

      throw Exception("Errore status utente: ${response.statusCode}");
    } catch (e) {
      print("Errore getUserStatus: $e");

      return {
        "enabled": false,
        "requested": false,
      };
    }
  }
}