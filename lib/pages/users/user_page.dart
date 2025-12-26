import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/logiche/auth/auth_delete_service.dart';
import 'package:tipicooo/logiche/notifications/notification_state.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';

import '../../widgets/base_page.dart';
import '../../theme/app_colors.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  String? userName;

  final AuthDeleteService _deleteService = AuthDeleteService();

  final labels = [
    "Dashboard Ufficio",
    "Lavora con noi",
    "Accedi o registra un’attività o associazione",
    "Accedi al Welfare Aziendale",
    "Liberi professionisti",
    "Dashboard Utente",
    "Elimina Profilo", // 👈 resta nella lista
  ];

  static const double horizontalPadding = 40;
  static const double verticalPadding = 28;

  double maxWidth = 0;
  double maxHeight = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMaxButtonSize(context);
      setState(() {});
    });
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

  // 🔥 MODALE + ELIMINAZIONE PROFILO
  Future<void> _confirmDelete() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Elimina Profilo"),
          content: const Text(
            "Sei sicuro di voler eliminare definitivamente il tuo profilo?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annulla"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Elimina",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // Loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
    );

    // Elimina utente
    await _deleteService.deleteCurrentUser();

    // Logout
    await _deleteService.logoutAfterDeletion();

    // Attiva notifica
    NotificationState.hasUnread.value = true;

    // Chiudi loader
    Navigator.of(context).pop();

    // Torna alla Home
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),

            if (userName == null)
              const CircularProgressIndicator()
            else
              Text(
                userName!,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 40),

            // Pulsanti principali
            for (var label in labels) ...[
              _buildCenteredButton(
                label: label,
                onPressed: () {
                  if (label == "Elimina Profilo") {
                    _confirmDelete(); // 👈 ora funziona
                  }
                },
              ),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _calculateMaxButtonSize(BuildContext context) {
    double w = 0;
    double h = 0;

    final maxTextWidth = MediaQuery.of(context).size.width - 32;

    for (var text in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
      )..layout(maxWidth: maxTextWidth);

      if (painter.width > w) w = painter.width;
      if (painter.height > h) h = painter.height;
    }

    maxWidth = w + horizontalPadding;
    maxHeight = h + verticalPadding;
  }

  Widget _buildCenteredButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: BlueNarrowButton(
          label: label,
          onPressed: onPressed,
        ),
      ),
    );
  }
}