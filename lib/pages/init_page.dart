import 'package:flutter/material.dart';

import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/logiche/requests/user_request_service.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';

import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/theme/app_colors.dart';
import 'package:tipicooo/theme/app_text_styles.dart';

class InitPage extends StatefulWidget {
  const InitPage({super.key});

  @override
  State<InitPage> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1) Configura Amplify
    await AuthService.configure();

    // 2) Inizializza AuthState
    await AuthState.initialize();
    // 3) Routing logico
    if (AuthState.isUserLoggedIn) {
      // Utente loggato → aggiorna stato per notifiche e atterra in Home
      await UserRequestService.resetAdminPendingCount();
      await ActivityRequestService.resetAdminPendingCount();
      await UserRequestService.getUserStatus();
      await UserRequestService.startAdminPolling();
      await ActivityRequestService.startAdminPolling();
      await ActivityRequestService.checkLatestStatus();
      _go(AppRoutes.home);
      return;
    }

    // Utente non loggato → Home/Login
    _go(AppRoutes.home);
  }

  void _go(String route) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: "Caricamento...",
      showBack: false,
      showHome: false,
      showBell: false,
      showLogout: false,

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: AppColors.primaryBlue),
            SizedBox(height: 20),
            Text(
              "Inizializzazione...",
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
