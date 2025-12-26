import 'package:flutter/material.dart';
import '../widgets/base_page.dart';
import '../widgets/app_bottom_nav.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_buttons.dart'; // contiene RoundedYellowButton
import 'package:tipicooo/utils/button_size_calculator.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final labels = ["Login", "Registrati"];
    final buttonSize = ButtonSizeCalculator.calculate(labels, context);

    return BasePage(
      headerTitle: 'Unisciti a noi',
      showBell: false,
      showBack: false,
      showHome: true,
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Benvenuto! Scegli come procedere:",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // 🟡 LOGIN
            SizedBox(
              width: buttonSize.width,
              height: buttonSize.height,
              child: RoundedYellowButton(
                label: "Login",
                icon: Icons.login,
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
              ),
            ),

            const SizedBox(height: 16),

            // 🟡 REGISTRATI
            SizedBox(
              width: buttonSize.width,
              height: buttonSize.height,
              child: RoundedYellowButton(
                label: "Registrati",
                icon: Icons.person_add,
                onPressed: () {
                  Navigator.pushNamed(context, '/signup');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}