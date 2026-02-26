import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/widgets/base_page.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

import 'package:tipicooo/pages/waiting_room_page.dart';

import 'package:tipicooo/logiche/requests/user_request_service.dart';
import 'package:tipicooo/logiche/requests/office_access_service.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';

import 'package:url_launcher/url_launcher.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  static const String _primaryAdminEmail = "carlo.mertolini@gmail.com";
  String? fullName;
  bool _isOpeningOffice = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _syncOfficeStatusAndNotifications();
  }

  Future<void> _syncOfficeStatusAndNotifications() async {
    await UserRequestService.getUserStatus();
    await ActivityRequestService.checkLatestStatus();
  }

  Future<void> _loadUserData() async {
    final attributes = await AuthService.instance.getUserAttributes();

    if (attributes.isEmpty) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
      return;
    }

    final name = attributes['given_name'] ?? "";
    final emailFallback = attributes['email'] ?? "Utente";

    final computedName = name.isNotEmpty
        ? name.split(" ").first
        : emailFallback;

    if (!mounted) return;
    setState(() {
      fullName = computedName.trim();
    });
  }

  Future<void> _logout() async {
    // AuthService.logout ora non blocca sul signOut remoto.
    await AuthService.instance.logout();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  Future<void> _openOffice({bool skipStatusCheck = false}) async {
    if (!OfficeAccessService.canOpenOfficeNow()) {
      final left = OfficeAccessService.remainingCooldown().inSeconds;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Ufficio già aperto. Attendi ${left > 0 ? left : 1} secondi.",
            ),
          ),
        );
      }
      return;
    }

    if (!skipStatusCheck) {
      // Verifica stato accesso prima di aprire l’ufficio
      final status = await UserRequestService.getUserStatus();
      final enabled = status["enabled"] == true;

      if (!enabled) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WaitingRoomPage()),
        );
        return;
      }
    }

    final code = await OfficeAccessService.requestOfficeCode();

    if (code == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore: impossibile aprire l'ufficio.")),
      );
      return;
    }

    final officeUrl = "https://ilpassaparoladicarlo.com/office/?code=$code";

    OfficeAccessService.markOfficeOpenedNow();
    await launchUrl(Uri.parse(officeUrl), mode: LaunchMode.externalApplication);
  }

  Future<void> _handleOpenOfficeTap() async {
    if (_isOpeningOffice) return;
    setState(() => _isOpeningOffice = true);
    try {
      final attrs = await AuthService.instance.getUserAttributes();
      final email = (attrs["email"] ?? "").trim().toLowerCase();
      final isPrimaryAdmin = email == _primaryAdminEmail;

      if (isPrimaryAdmin) {
        await _openOffice(skipStatusCheck: true);
        return;
      }

      final status = await UserRequestService.getUserStatus();
      final enabled = status["enabled"] == true;

      if (!enabled) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WaitingRoomPage()),
        );
        return;
      }

      await _openOffice();
    } finally {
      if (mounted) {
        setState(() => _isOpeningOffice = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: false,
      headerTitle: 'Benvenuto',
      showHome: true,
      showBack: false,
      showBell: true,
      showProfile: true,
      showLogout: true,
      onLogout: _logout,
      body: AppBodyLayout(
        children: [
          if (fullName == null) ...[
            const CircularProgressIndicator(color: AppColors.primaryBlue),
            const SizedBox(height: 20),
            const Text(
              "Caricamento...",
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              fullName!,
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
          ],

          BlueNarrowButton(
            label: "Attività",
            icon: Icons.factory_outlined,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.userActivities);
            },
          ),

          const SizedBox(height: 20),

          BlueNarrowButton(
            label: "Portafoglio",
            icon: Icons.trending_up,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.userActions);
            },
          ),

          const SizedBox(height: 20),

          BlueNarrowButton(
            label: "Profilo",
            icon: Icons.person_outline,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.profile);
            },
          ),

          const SizedBox(height: 20),

          // 🔵 ENTRA IN UFFICIO — flusso completo
          BlueNarrowButton(
            label: _isOpeningOffice ? "Attendi..." : "Ufficio",
            icon: Icons.business_center,
            onPressed: _isOpeningOffice ? () {} : _handleOpenOfficeTap,
          ),
          if (_isOpeningOffice) ...[
            const SizedBox(height: 10),
            const CircularProgressIndicator(color: AppColors.primaryBlue),
          ],

        ],
      ),
    );
  }
}
