import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/logiche/auth/auth_delete_service.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';

// ⭐ Nuovo sistema notifiche
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';

import '../../widgets/base_page.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';
import 'package:tipicooo/widgets/app_bottom_nav.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  String? userName;

  final AuthDeleteService _deleteService = AuthDeleteService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final attributes = await AuthService().getUserAttributes();

    final name = attributes['given_name'] ??
        attributes['name'] ??
        attributes['email'] ??
        "Utente";

    setState(() {
      userName = name;
    });
  }

  Future<void> _logout() async {
    try {
      await AuthService().logout();
    } catch (e) {
      debugPrint("Errore logout: $e");
    }

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  Future<void> _confirmDelete() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Elimina Profilo",
            style: AppTextStyles.body,
          ),
          content: const Text(
            "Sei sicuro di voler eliminare definitivamente il tuo profilo?",
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Annulla",
                style: AppTextStyles.body,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                "Elimina",
                style: AppTextStyles.body.copyWith(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
    );

    await _deleteService.deleteCurrentUser();
    await _deleteService.logoutAfterDeletion();

    // ⭐ NUOVO SISTEMA NOTIFICHE PROFESSIONALE
    NotificationController.instance.addNotification(
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Profilo eliminato',
        message: 'Il tuo profilo è stato eliminato con successo.',
        timestamp: DateTime.now(),
      ),
    );

    Navigator.of(context).pop();

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
      arguments: {'deleted': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: 'Benvenuto',
      showHome: true,
      showLogout: true,
      onLogout: _logout,

      bottomNavigationBar: const AppBottomNav(currentIndex: 2),

      body: AppBodyLayout(
        children: [
          if (userName == null) ...[
            const CircularProgressIndicator(color: AppColors.primaryBlue),
            const SizedBox(height: 20),
            const Text(
              "Caricamento...",
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              userName!,
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],

          DangerButton(
            label: "Elimina Profilo",
            icon: Icons.delete_forever,
            onPressed: _confirmDelete,
          ),
        ],
      ),
    );
  }
}