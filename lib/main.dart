// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:tipicooo_office/pages/home_admin.dart';
import 'package:tipicooo_office/logiche/office_auth.dart';

const String _officeApiBase =
    "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod";

Future<String?> _exchangeOfficeCode(String code) async {
  try {
    final response = await http.post(
      Uri.parse("$_officeApiBase/office-code/exchange"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"code": code}),
    );

    if (response.statusCode != 200) {
      debugPrint("Errore exchange code: ${response.statusCode}");
      return null;
    }

    final data = jsonDecode(response.body);
    final token = data["token"];
    if (token is String && token.isNotEmpty) {
      return token;
    }
  } catch (e) {
    debugPrint("Errore exchange code: $e");
  }

  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ 1. Leggiamo il code dall’URL (flusso sicuro)
  final uri = Uri.base;
  final code = uri.queryParameters["code"];
  final legacyToken = uri.queryParameters["token"];
  final section = (uri.queryParameters["section"] ?? "").trim().toLowerCase();

  String? token;

  if (code != null && code.isNotEmpty) {
    token = await _exchangeOfficeCode(code);
  }

  // Fallback legacy (se arriva ancora ?token=...)
  token ??= (legacyToken != null && legacyToken.isNotEmpty)
      ? legacyToken
      : null;

  // ⭐ 2. Se presente, lo salviamo in localStorage
  if (token != null && token.isNotEmpty) {
    OfficeAuth.setToken(token);
    debugPrint("TOKEN ADMIN SALVATO");

    // Pulisci la query string (non lasciare code/token nell’URL)
    html.window.history.replaceState(null, '', uri.path);
  } else {
    debugPrint("NESSUN TOKEN TROVATO NELL'URL");
  }

  // ⭐ 3. Avviamo l’app (senza Amplify)
  int initialIndex = -1;
  if (section == "users") initialIndex = 2;
  if (section == "activities") initialIndex = 1;
  if (section == "notifications") initialIndex = 3;
  if (section == "admin") initialIndex = 0;

  runApp(TipicoooOfficeApp(initialSelectedIndex: initialIndex));
}

class TipicoooOfficeApp extends StatelessWidget {
  final int initialSelectedIndex;

  const TipicoooOfficeApp({super.key, this.initialSelectedIndex = -1});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tipic.ooo Ufficio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: HomeAdmin(initialSelectedIndex: initialSelectedIndex),
    );
  }
}
