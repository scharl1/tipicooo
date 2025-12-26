import 'package:flutter/material.dart';
import '../widgets/base_page.dart';
import '../widgets/app_bottom_nav.dart';
import '../theme/app_colors.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: 'Preferiti',
      showBell: false,   // 🚫 niente campanella
      showBack: false,    // ✅ freccia indietro
      showHome: true,    // ✅ icona home
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: const Center(
        child: Text(
          'Nessun preferito disponibile',
          style: TextStyle(
            color: AppColors.black,       // ✅ colore centralizzato
            fontWeight: FontWeight.bold,  // ✅ grassetto
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}