import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthState {
  /// Stato reattivo del login
  static final ValueNotifier<bool> isLoggedIn = ValueNotifier(false);

  /// 🔥 Utente Cognito corrente
  static AuthUser? _currentUser;

  /// Getter comodo per ottenere l'ID Cognito
  static String get userId => _currentUser?.userId ?? '';

  /// Getter per l'utente completo
  static AuthUser? get user => _currentUser;

  /// Inizializza lo stato leggendo Cognito
  static Future<void> initialize() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();

      if (session.isSignedIn) {
        // Recupera l'utente Cognito
        _currentUser = await Amplify.Auth.getCurrentUser();

        isLoggedIn.value = true;
      } else {
        isLoggedIn.value = false;
        _currentUser = null;
        await _clearLocalState();
      }
    } catch (_) {
      isLoggedIn.value = false;
      _currentUser = null;
      await _clearLocalState();
    }
  }

  /// Imposta login manualmente (dopo login Cognito)
  static void setLoggedIn() {
    isLoggedIn.value = true;
  }

  /// Imposta logout manualmente (dopo logout Cognito)
  static Future<void> setLoggedOut() async {
    isLoggedIn.value = false;
    _currentUser = null;
    await _clearLocalState();
  }

  /// 🔥 Pulisce eventuali dati locali (pending email OTP, ecc.)
  static Future<void> _clearLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove("pending_email");
  }

  /// 🔥 Metodo comodo per routing
  static bool get isUserLoggedIn => isLoggedIn.value;
}