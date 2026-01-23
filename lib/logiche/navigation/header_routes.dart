import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../auth/auth_state.dart';
import 'app_routes.dart';

/// Funzioni centralizzate per la navigazione dall'header.
/// Tutti i pulsanti dell'AppBar usano queste funzioni.
class HeaderRoutes {

  /// Torna alla Home sostituendo la pagina corrente
  static void navigateToHome(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  /// Apri la pagina notifiche
  static void goToNotifications(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.notifications);
  }

  /// 🔵 Vai alla pagina utente SE loggato
  /// 🔵 Altrimenti vai alla pagina login (profile_page)
  static void goToProfile(BuildContext context) {
    final loggedIn = AuthState.isLoggedIn.value;

    if (loggedIn) {
      Navigator.pushNamed(context, AppRoutes.user);
    } else {
      Navigator.pushNamed(context, AppRoutes.profile);
    }
  }

  /// ⭐ Vai SEMPRE alla UserPage (solo per header da loggato)
  static void goToUserPage(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.user);
  }

  /// 🔥 LOGOUT REALE CON COGNITO + RIMOZIONE STACK
  static Future<void> logout(BuildContext context) async {
    try {
      // Logout globale Cognito → invalida tutte le sessioni
      await Amplify.Auth.signOut(
        options: const SignOutOptions(globalSignOut: true),
      );

      // Torna alla HOME e rimuove tutto lo stack
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante il logout: ${e.message}")),
      );
    }
  }

  /// Torna indietro se possibile, altrimenti vai in Home
  static void goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      navigateToHome(context);
    }
  }
}