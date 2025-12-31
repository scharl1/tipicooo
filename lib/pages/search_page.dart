import 'package:flutter/material.dart';
import '../widgets/base_page.dart';
import '../widgets/app_bottom_nav.dart';
import '../theme/app_text_styles.dart';
import '../widgets/layout/app_body_layout.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: 'Intorno a te',
      showBack: false,
      showHome: true,
      showBell: false,
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),

      body: AppBodyLayout(
        children: const [
          Text(
            'Funzionalità di ricerca non ancora attivate',
            textAlign: TextAlign.center,
            style: AppTextStyles.pageMessage,
          ),
        ],
      ),
    );
  }
}