import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_state.dart';

class AuthDeleteService {
  /// Elimina definitivamente l'utente corrente da Cognito
  Future<void> deleteCurrentUser() async {
    try {
      // 🔥 Se non c’è sessione, evita crash
      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        debugPrint("Nessun utente loggato, impossibile eliminare.");
        return;
      }

      await Amplify.Auth.deleteUser();
      debugPrint("Utente eliminato correttamente.");

      // 🔥 Pulisci stato locale
      AuthState.setLoggedOut();

      final prefs = await SharedPreferences.getInstance();
      prefs.remove("pending_email");

    } on AuthException catch (e) {
      debugPrint("Errore eliminazione utente: ${e.message}");
    }
  }
}