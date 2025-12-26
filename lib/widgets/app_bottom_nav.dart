import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../logiche/navigation/bottom_nav_routes.dart';
import '../logiche/auth/auth_state.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({
    super.key,
    this.currentIndex = -1,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthState.isLoggedIn,
      builder: (context, loggedIn, _) {
        return BottomNavigationBar(
          currentIndex: currentIndex >= 0 ? currentIndex : 0,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: Colors.grey,

          onTap: (index) {
            if (index == 2 && loggedIn) {
              return;
            }

            BottomNavRoutes.navigateToIndex(context, index, currentIndex);
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