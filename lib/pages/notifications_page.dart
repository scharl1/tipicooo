import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/theme/app_colors.dart';
import 'package:tipicooo/logiche/notifications/notification_state.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();

    // 👇 Quando apro la pagina notifiche, segno tutto come letto
    NotificationState.hasUnread.value = false;
  }

  @override
  Widget build(BuildContext context) {
    // Recupera eventuali argomenti passati dal Navigator
    final args = ModalRoute.of(context)?.settings.arguments;

    // Controlla se è stata eliminata l’utenza
    final bool deleted = args is Map && args['deleted'] == true;

    return BasePage(
      headerTitle: "Le tue notifiche",
      showBell: false,
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔔 Notifica eliminazione profilo
            if (deleted)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.accentYellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentYellow),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Il tuo profilo è stato eliminato con successo.",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Placeholder per notifiche future
            const Text(
              "Non ci sono altre notifiche al momento.",
              style: TextStyle(
                fontSize: 16,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}