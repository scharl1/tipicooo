import 'package:flutter/material.dart';
import '../widgets/base_page.dart';
import '../widgets/app_bottom_nav.dart';
import '../theme/app_text_styles.dart';
import '../widgets/custom_buttons.dart';
import '../widgets/layout/app_body_layout.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: 'Unisciti a noi',
      showBell: false,
      showBack: true,
      showHome: false,
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),

      body: AppBodyLayout(
        children: [
          const Text(
            "Benvenuto! Scegli come procedere:",
            textAlign: TextAlign.center,
            style: AppTextStyles.pageMessage,
          ),

          RoundedYellowButton(
            label: "Login",
            icon: Icons.login,
            onPressed: () {
              Navigator.pushNamed(context, "/login");
            },
          ),

          RoundedYellowButton(
            label: "Registrati",
            icon: Icons.person_add,
            onPressed: () {
              Navigator.pushNamed(context, "/signup");
            },
          ),
        ],
      ),
    );
  }
}