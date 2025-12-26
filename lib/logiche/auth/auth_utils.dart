import 'package:amplify_flutter/amplify_flutter.dart';
import 'auth_state.dart';

class AuthUtils {
  static Future<bool> isLoggedIn() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      AuthState.isLoggedIn.value = session.isSignedIn; // 👈 aggiorna lo stato globale
      return session.isSignedIn;
    } catch (_) {
      AuthState.isLoggedIn.value = false;
      return false;
    }
  }
}