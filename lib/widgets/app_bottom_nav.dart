import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../logiche/navigation/bottom_nav_routes.dart';
import '../logiche/auth/auth_state.dart';

/// Barra di navigazione inferiore universale.
/// Gestisce le tre sezioni principali dell’app.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({
    super.key,
    this.currentIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthState.isLoggedIn,
      builder: (context, loggedIn, _) {

        // ⭐ Protezione: se currentIndex è 3 (Home), la bottom nav non deve crashare
        final safeIndex = currentIndex > 2 ? 0 : currentIndex;

        return BottomNavigationBar(
          currentIndex: safeIndex,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: Colors.grey,

          onTap: (index) {
            // 🔵 BLOCCO PROFILO SE UTENTE LOGGATO
            if (index == 2 && loggedIn) {
              return;
            }

            // 🔵 BLOCCO CLICK SULLA PAGINA CORRENTE
            if (index == currentIndex) {
              return;
            }

            // 🔵 NAVIGAZIONE CENTRALIZZATA
            BottomNavRoutes.navigateToIndex(
              context,
              index,
              currentIndex,
            );
          },

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              label: 'Cerca',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              label: 'Preferiti',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profilo',
            ),
          ],
        );
      },
    );
  }
}