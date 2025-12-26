import 'package:flutter/material.dart';
import '../widgets/base_page.dart';
import '../widgets/app_bottom_nav.dart';
import '../theme/app_colors.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: 'Intorno a te',
      showBack: false,    // ✅ freccia indietro attiva
      showHome: true,    // ✅ icona home attiva
      showBell: false,   // 🚫 nasconde la campanella
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: const Center(
        child: Text(
          'Funzionalità di ricerca non ancora attivate',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}