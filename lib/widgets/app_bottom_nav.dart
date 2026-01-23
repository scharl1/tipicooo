import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../logiche/auth/auth_state.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({
    super.key,
    this.currentIndex = 0,
  });

  void _onTap(BuildContext context, int index, bool loggedIn) {
    // Se siamo in Home (currentIndex = -1), NON blocchiamo mai il tap
    if (currentIndex != -1 && index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, "/search");
        break;

      case 1:
        Navigator.pushReplacementNamed(context, "/favorites");
        break;

      case 2:
        if (loggedIn) {
          Navigator.pushReplacementNamed(context, "/user");
        } else {
          Navigator.pushReplacementNamed(context, "/login");
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthState.isLoggedIn,
      builder: (context, loggedIn, _) {
        // ⭐ Se currentIndex = -1 (Home), usiamo 0 per evitare crash
        final safeIndex = currentIndex == -1 ? 0 : currentIndex;

        return BottomNavigationBar(
          currentIndex: safeIndex,
          backgroundColor: AppColors.white,

          // ⭐ Se siamo in Home, nessuna icona deve sembrare attiva
          selectedItemColor:
              currentIndex == -1 ? Colors.grey : AppColors.primaryBlue,

          unselectedItemColor: Colors.grey,

          onTap: (index) => _onTap(context, index, loggedIn),

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