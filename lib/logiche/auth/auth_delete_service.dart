import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'auth_state.dart';
import 'package:tipicooo/logiche/requests/user_request_service.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/logiche/requests/purchase_service.dart';

class AuthDeleteService {
  static const String _baseUrl =
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod";

  Future<void> _logDeletedUser({
    required String reason,
    required String reasonNote,
  }) async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      await http.post(
        Uri.parse("$_baseUrl/deleted-users-log"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({"reason": reason, "reasonNote": reasonNote}),
      );
    } catch (e) {
      debugPrint("Errore log deleted user: $e");
    }
  }

  Future<void> _deleteUserRequests() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      await http.post(
        Uri.parse("$_baseUrl/user-delete-requests"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
      );
    } catch (e) {
      debugPrint("Errore deleteUserRequests: $e");
    }
  }

  /// Elimina definitivamente l'utente corrente da Cognito
  Future<bool> deleteCurrentUser({
    required String reason,
    required String reasonNote,
  }) async {
    try {
      // Ferma polling in corso per evitare chiamate mentre la sessione viene chiusa.
      UserRequestService.stopAdminPolling();
      ActivityRequestService.stopAdminPolling();
      PurchaseService.stopActivityPolling();

      // 🔥 Se non c’è sessione, evita crash
      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        debugPrint("Nessun utente loggato, impossibile eliminare.");
        return false;
      }

      await _logDeletedUser(reason: reason, reasonNote: reasonNote);
      await _deleteUserRequests();

      await Amplify.Auth.deleteUser();
      debugPrint("Utente eliminato correttamente.");

      // 🔥 Pulisci stato locale
      await AuthState.setLoggedOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("pending_email");

      return true;
    } on AuthException catch (e) {
      debugPrint("Errore eliminazione utente: ${e.message}");
      return false;
    } catch (e) {
      debugPrint("Errore eliminazione utente (unexpected): $e");
      return false;
    }
  }
}
