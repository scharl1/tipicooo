import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/logiche/config/api_endpoints.dart';

class AdminService {
  static const String baseUrl =
      ApiEndpoints.adminBaseUrl;

  static Future<Map<String, String>> _headers() async {
    final idToken = await AuthService.instance.getIdToken();
    if (idToken == null) throw Exception("ID Token non trovato");

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $idToken",
    };
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final headers = await _headers();
    final url = Uri.parse("$baseUrl$path");
    return http.post(url, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> delete(String path) async {
    final headers = await _headers();
    final url = Uri.parse("$baseUrl$path");
    return http.delete(url, headers: headers);
  }

  static Future<http.Response> get(String path) async {
    final headers = await _headers();
    final url = Uri.parse("$baseUrl$path");
    return http.get(url, headers: headers);
  }
}
