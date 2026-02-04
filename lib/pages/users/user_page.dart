import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/logiche/auth/auth_delete_service.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';

import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';

import '../../widgets/base_page.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

import 'package:tipicooo/pages/waiting_room_page.dart';
import 'package:tipicooo/pages/access_pending_page.dart';

import 'package:tipicooo/logiche/requests/user_request_service.dart';

import 'package:url_launcher/url_launcher.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  String? fullName;

  final AuthDeleteService _deleteService = AuthDeleteService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final attributes = await AuthService.instance.getUserAttributes();

    if (attributes.isEmpty) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
      return;
    }

    final name = attributes['given_name'] ?? "";
    final emailFallback = attributes['email'] ?? "Utente";

    final computedName =
        name.isNotEmpty ? name.split(" ").first : emailFallback;

    if (!mounted) return;
    setState(() {
      fullName = computedName.trim();
    });
  }

  // ⭐ Decodifica JWT
  Map<String, dynamic> _parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Token JWT non valido');
    }

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));

    return json.decode(decoded);
  }

  // ⭐ Controllo se l’utente è admin (gruppo Cognito)
  Future<bool> _isAdmin() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final payload = _parseJwt(idToken);

      final groups = payload["cognito:groups"];

      if (groups is List && groups.contains("admin")) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("Errore controllo admin: $e");
      return false;
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService.instance.logout();
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

    AuthState.setLoggedOut();

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
      showBack: false,
      showBell: false,
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

          // 🔵 SUGGERISCI
          BlueNarrowButton(
            label: "Suggerisci ai miei contatti",
            icon: Icons.lightbulb_outline,
            onPressed: () {
              Navigator.pushNamed(context, '/suggest');
            },
          ),

          const SizedBox(height: 20),

          // 🔵 REGISTRA ATTIVITÀ
          BlueNarrowButton(
            label: "Registra attività",
            icon: Icons.store_mall_directory,
            onPressed: () {
              Navigator.pushNamed(context, '/register_activity');
            },
          ),

          const SizedBox(height: 20),

          // 🔵 ENTRA IN UFFICIO — flusso completo
          BlueNarrowButton(
            label: "Entra in ufficio",
            icon: Icons.business_center,
            onPressed: () async {
              final admin = await _isAdmin();

              if (admin) {
                const officeUrl = "https://ilpassaparoladicarlo.com/office";
                final uri = Uri.parse(officeUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                return;
              }

              final status = await UserRequestService.getUserStatus();

              final enabled = status["enabled"] == true;
              final requested = status["requested"] == true;

              if (enabled) {
                const officeUrl = "https://ilpassaparoladicarlo.com/office";
                final uri = Uri.parse(officeUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                return;
              }

              if (!requested) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WaitingRoomPage()),
                );
                return;
              }

              if (requested && !enabled) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccessPendingPage()),
                );
                return;
              }
            },
          ),

          const SizedBox(height: 20),

          // 🔴 ELIMINA PROFILO
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