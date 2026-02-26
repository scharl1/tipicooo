import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/requests/staff_join_service.dart';
import 'package:tipicooo/theme/app_colors.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

class JoinStaffPage extends StatefulWidget {
  const JoinStaffPage({super.key});

  @override
  State<JoinStaffPage> createState() => _JoinStaffPageState();
}

class _JoinStaffPageState extends State<JoinStaffPage> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() => _loading = true);
    final ok = await StaffJoinService.requestJoin(
      activityRequestId: code,
      notifyLocal: false,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? "Richiesta inviata. La richiesta dovrà essere approvata dal proprietario. Grazie"
              : "Errore: impossibile inviare la richiesta.",
        ),
      ),
    );

    if (ok) {
      final inviterEmail = StaffJoinService.lastInviterEmail.trim();
      final title = inviterEmail.isNotEmpty
          ? "Richiesta da parte di $inviterEmail"
          : "Richiesta dipendente inviata";
      final message = inviterEmail.isNotEmpty
          ? "Richiesta da parte di $inviterEmail inviata. In attesa di conferma."
          : "La richiesta dovrà essere approvata dal proprietario. Grazie";

      NotificationController.instance.addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          message: message,
          timestamp: DateTime.now(),
          action: "open_staff_join",
        ),
      );
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: false,
      headerTitle: "Lavora in un'attività",
      showBack: true,
      showHome: true,
      showProfile: true,
      showBell: true,
      showLogout: false,
      body: AppBodyLayout(
        children: [
          const Text(
            "Inserisci il codice attività",
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            "Il proprietario ti fornirà un codice (ID attività). Dopo l'approvazione potrai accettare i pagamenti.",
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: "Es. 4bcbb74f-....",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          else
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text("Invia richiesta"),
            ),
        ],
      ),
    );
  }
}
