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
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        _safeNavigate(context, AppRoutes.search);
        break;

      case 1:
        _safeNavigate(context, AppRoutes.favorites);
        break;

      case 2:
        final loggedIn = await AuthUtils.isLoggedIn();

        if (loggedIn) {
          debugPrint("Profilo cliccato ma utente già loggato → nessuna navigazione");
          return;
        }

        _safeNavigate(context, AppRoutes.profile);
        break;

      default:
        debugPrint("Indice bottom nav non riconosciuto: $index");
    }
  }

  static void _safeNavigate(BuildContext context, String routeName) {
    try {
      Navigator.pushReplacementNamed(context, routeName);
    } catch (e) {
      debugPrint("Errore navigazione verso $routeName: $e");
    }
  }
}