import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';

import '../widgets/base_page.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/layout/app_body_layout.dart';
import '../widgets/custom_buttons.dart';
import '../theme/app_text_styles.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthState.isLoggedIn,
      builder: (context, loggedIn, _) {
        return BasePage(
          headerTitle: "Tipic.ooo",

          showBell: true,
          showProfile: loggedIn,
          showHome: false,
          showBack: false,
          showLogout: false,

          // ⭐ Home NON deve avere un indice della bottom bar
          bottomNavigationBar: const AppBottomNav(currentIndex: -1),

          body: AppBodyLayout(
            children: [
              const Text(
                "Benvenuto in Tipic.ooo! Siamo in continua evoluzione.\nSe trovi bug, segnalaceli. Grazie!",
                textAlign: TextAlign.center,
                style: AppTextStyles.pageMessage,
              ),

              RoundedYellowButton(
                label: "Vai al Test",
                icon: Icons.arrow_forward,
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.testPage);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}