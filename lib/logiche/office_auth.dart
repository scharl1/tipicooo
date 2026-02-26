// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Auth minimale per Tipic.ooo Office.
///
/// Il token "adminToken" è un bearer rilasciato dal backend office-code.
/// Quando viene revocato (utente eliminato / permessi rimossi / token scaduto),
/// puliamo lo storage e notifichiamo l'app così da mostrare il gate di accesso.
class OfficeAuth {
  static const String _tokenKey = "adminToken";

  // Incrementa ogni volta che il token cambia (set/clear) per forzare refresh UI.
  static final ValueNotifier<int> tokenEpoch = ValueNotifier<int>(0);

  static String? get token {
    final t = html.window.localStorage[_tokenKey];
    if (t == null || t.isEmpty) return null;
    return t;
  }

  static void setToken(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    html.window.localStorage[_tokenKey] = trimmed;
    tokenEpoch.value = tokenEpoch.value + 1;
  }

  static void clearToken() {
    html.window.localStorage.remove(_tokenKey);
    tokenEpoch.value = tokenEpoch.value + 1;
  }
}
