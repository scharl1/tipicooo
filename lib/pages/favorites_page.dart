import 'package:flutter/material.dart';
import '../widgets/base_page.dart';
import '../widgets/app_bottom_nav.dart';
import '../theme/app_text_styles.dart';
import '../widgets/layout/app_body_layout.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: 'Preferiti',
      showBell: false,
      showBack: false,
      showHome: true,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),

      body: AppBodyLayout(
        children: const [
          Text(
            'Nessun preferito disponibile',
            style: AppTextStyles.pageMessage,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}