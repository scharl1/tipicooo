import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/pages/users/staff/join_staff_page.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

import '../../widgets/base_page.dart';

class UserActionsPage extends StatelessWidget {
  const UserActionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: AuthState.isLoggedIn,
      builder: (context, loggedIn, _) {
        final isLoggedIn = loggedIn == true;
        return BasePage(
          scrollable: true,
          headerTitle: "Le mie azioni",
          showBell: isLoggedIn,
          showProfile: isLoggedIn,
          showHome: true,
          showBack: true,
          showLogout: false,
          body: AppBodyLayout(
            children: [
              const SizedBox(height: 10),
              if (!isLoggedIn) ...[
                const Text(
                  "Devi essere loggato per accedere a questa sezione.",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                BlueNarrowButton(
                  label: "Torna alla Home",
                  icon: Icons.home,
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.home,
                      (route) => false,
                    );
                  },
                ),
              ] else ...[
                const Text(
                  "Seleziona un'azione:",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                BlueNarrowButton(
                  label: "Cashback",
                  icon: Icons.account_balance_wallet_outlined,
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.userCashback);
                  },
                ),
                const SizedBox(height: 20),
                BlueNarrowButton(
                  label: "Suggerisci",
                  icon: Icons.lightbulb_outline,
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.suggest);
                  },
                ),
                const SizedBox(height: 20),
                BlueNarrowButton(
                  label: "Fai crescere Tipic.ooo",
                  icon: Icons.trending_up,
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.affiliateActivity);
                  },
                ),
                const SizedBox(height: 20),
                BlueNarrowButton(
                  label: "Lavora in un'attività",
                  icon: Icons.badge_outlined,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const JoinStaffPage(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
