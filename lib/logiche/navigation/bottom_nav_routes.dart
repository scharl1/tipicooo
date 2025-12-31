// lib/logiche/navigation/bottom_nav_routes.dart

import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../auth/auth_utils.dart'; // 👈 serve per controllare login

class BottomNavRoutes {
  static void navigateToIndex(
    BuildContext context,
    int index,
    int currentIndex,
  ) async {

    // Permetti sempre la navigazione verso Cerca (index 0)
    if (index == currentIndex && index != 0) return;

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
        final loggedIn = await AuthUtils.isLoggedIn();

        if (loggedIn) {
          debugPrint("Profilo cliccato ma utente già loggato → nessuna navigazione");
          return;
        }

        _safeNavigate(context, AppRoutes.profile);
        break;

      // 🔵 HOME (nuovo index 3)
      case 3:
        _safeNavigate(context, AppRoutes.home);
        break;

      // 🔵 DEFAULT
      default:
        debugPrint("Indice bottom nav non riconosciuto: $index");
    }
  }

  static void _safeNavigate(BuildContext context, String routeName) {
    // ⭐ Protezione contro async gaps
    if (!context.mounted) return;

    try {
      Navigator.pushReplacementNamed(context, routeName);
    } catch (e) {
      debugPrint("Errore navigazione verso $routeName: $e");
    }
  }
}