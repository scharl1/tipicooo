// lib/logiche/navigation/bottom_nav_routes.dart

import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../auth/auth_state.dart';

class BottomNavRoutes {
  static void navigateToIndex(
    BuildContext context,
    int index,
    int currentIndex,
  ) {
    // ⭐ Normalizzazione dell’indice
    final safeCurrent = (currentIndex < 0 || currentIndex > 2) ? 0 : currentIndex;

    // Evita ricarichi inutili
    if (index == safeCurrent) return;

    switch (index) {

      // 🔵 CERCA
      case 0:
        _safeNavigate(context, AppRoutes.search);
        break;

      // 🔵 PREFERITI
      case 1:
        _safeNavigate(context, AppRoutes.favorites);
        break;

      // 🔵 PROFILO
      case 2:
        final loggedIn = AuthState.isLoggedIn.value;

        if (loggedIn) {
          // Utente loggato → icona NON cliccabile
          debugPrint("Profilo cliccato ma utente già loggato → nessuna navigazione");
          return;
        }

        // Utente NON loggato → vai a ProfilePage
        _safeNavigate(context, AppRoutes.profile);
        break;

      // 🔵 DEFAULT
      default:
        debugPrint("Indice bottom nav non riconosciuto: $index");
    }
  }

  // ⭐ Metodo per aprire la ProfilePage da bottom nav
  static void goToProfile(BuildContext context) {
    _safeNavigate(context, AppRoutes.profile);
  }

  static void _safeNavigate(BuildContext context, String routeName) {
    if (!context.mounted) return;

    try {
      Navigator.pushReplacementNamed(context, routeName);
    } catch (e) {
      debugPrint("Errore navigazione verso $routeName: $e");
    }
  }
}