import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class AuthDeleteService {
  Future<void> deleteCurrentUser() async {
    try {
      await Amplify.Auth.deleteUser();
    } on AuthException catch (e) {
      debugPrint("Errore eliminazione utente: ${e.toString()}");
    }
  }

  Future<void> logoutAfterDeletion() async {
    try {
      await Amplify.Auth.signOut();
    } on AuthException catch (e) {
      debugPrint("Errore logout dopo eliminazione: ${e.toString()}");
    }
  }
}