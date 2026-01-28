import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:tipicooo/amplifyconfiguration.dart';
import 'auth_state.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static bool _isConfigured = false;

  // ---------------------------------------------------------------------------
  // CONFIGURAZIONE AMPLIFY
  // ---------------------------------------------------------------------------
  static Future<void> configure() async {
    if (_isConfigured) {
      debugPrint("⚠️ Amplify già configurato");
      return;
    }

    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.addPlugin(AmplifyAPI());
      await Amplify.configure(amplifyconfig);

      _isConfigured = true;
      debugPrint("✅ Amplify configurato");
    } catch (e, st) {
      debugPrint("❌ ERRORE CONFIGURAZIONE AMPLIFY:");
      debugPrint(e.toString());
      debugPrint(st.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // LOGIN / SIGNUP — HOSTED UI
  // ---------------------------------------------------------------------------
  Future<void> signInWithHostedUI() async {
    await Amplify.Auth.signInWithWebUI();
    AuthState.setLoggedIn();
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------
  Future<void> logout() async {
    await Amplify.Auth.signOut();
    AuthState.setLoggedOut();
  }

  // ---------------------------------------------------------------------------
  // LETTURA ATTRIBUTI UTENTE DAL TOKEN JWT
  // ---------------------------------------------------------------------------
  Future<Map<String, String>> getUserAttributes() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      final tokens = session.userPoolTokensResult.valueOrNull;
      if (tokens == null) return {};

      final idToken = tokens.idToken.raw;
      final payload = _parseJwt(idToken);

      return {
        "email": payload["email"] ?? "",
        "given_name": payload["given_name"] ?? "",
        "family_name": payload["family_name"] ?? "",
      };
    } catch (e) {
      debugPrint("Errore getUserAttributes: $e");
      return {};
    }
  }

  Map<String, dynamic> _parseJwt(String token) {
    final parts = token.split('.');
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return json.decode(decoded);
  }

  // ---------------------------------------------------------------------------
  // OTTENERE IL TOKEN JWT
  // ---------------------------------------------------------------------------
  Future<String?> getIdToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();

      if (session is CognitoAuthSession) {
        final tokens = session.userPoolTokensResult.valueOrNull;
        return tokens?.idToken.raw;
      }

      return null;
    } catch (e) {
      debugPrint("Errore ottenimento token: $e");
      return null;
    }
  }
}