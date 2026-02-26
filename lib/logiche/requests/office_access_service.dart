import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

class OfficeAccessService {
  static const String baseUrl =
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod";
  static DateTime? _lastLaunchAt;
  static const Duration _launchCooldown = Duration(seconds: 20);

  static bool canOpenOfficeNow() {
    final last = _lastLaunchAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= _launchCooldown;
  }

  static Duration remainingCooldown() {
    final last = _lastLaunchAt;
    if (last == null) return Duration.zero;
    final elapsed = DateTime.now().difference(last);
    final left = _launchCooldown - elapsed;
    if (left.isNegative) return Duration.zero;
    return left;
  }

  static void markOfficeOpenedNow() {
    _lastLaunchAt = DateTime.now();
  }

  static Future<String?> requestOfficeCode() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.valueOrNull?.idToken.raw;

      if (idToken == null || idToken.isEmpty) {
        return null;
      }

      final url = Uri.parse("$baseUrl/office-code");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
      );

      if (response.statusCode != 200) {
        debugPrint("Errore office-code: ${response.statusCode}");
        return null;
      }

      final data = jsonDecode(response.body);
      final code = data["code"];
      if (code is String && code.isNotEmpty) {
        return code;
      }

      return null;
    } catch (e) {
      debugPrint("Errore requestOfficeCode: $e");
      return null;
    }
  }
}
