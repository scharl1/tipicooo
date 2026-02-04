import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';
import 'package:tipicooo/theme/app_text_styles.dart';

class AccessPendingPage extends StatelessWidget {
  const AccessPendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: "Tipic.ooo Office",
      showBack: true,
      showHome: true,
      showBell: false,
      showProfile: true,
      showLogout: false,

      body: AppBodyLayout(
        children: [
          const SizedBox(height: 40),

          // ⭐ Icona semaforo rosso
          Icon(
            Icons.stop_circle_rounded,
            size: 110,
            color: Colors.red.shade600,
          ),

          const SizedBox(height: 30),

          // ⭐ Titolo
          const Text(
            "Accesso in attesa di approvazione",
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle,
          ),

          const SizedBox(height: 16),

          // ⭐ Messaggio descrittivo
          const Text(
            "La tua richiesta è stata ricevuta.\n"
            "Un amministratore sta verificando i requisiti.\n"
            "Riceverai una notifica quando l’accesso sarà abilitato.",
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}