import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/theme/app_colors.dart';

// ⭐ Nuovo sistema notifiche
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();

    // ⭐ Segna tutte le notifiche come lette DOPO il build iniziale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationController.instance.markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationController.instance.notifications;

    return BasePage(
      headerTitle: "Le tue notifiche",
      showBack: true,
      showHome: false,
      showBell: false,
      showProfile: true,   // ⭐ AGGIUNTO PER COERENZA
      scrollable: false,   // ⭐ OBBLIGATORIO PER EVITARE CRASH

      body: notifications.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Non ci sono notifiche al momento.",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.black,
                ),
              ),
            )
          : Column(
              children: [
                Expanded( // ⭐ FIX: ListView ha ora altezza valida
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final n = notifications[index];

                      return Dismissible(
                        key: ValueKey(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          NotificationController.instance.deleteNotification(n.id);
                          setState(() {});
                        },
                        child: _buildNotificationTile(n),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNotificationTile(AppNotification n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentYellow.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentYellow),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications, color: AppColors.primaryBlue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  n.message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTimestamp(n.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);

    if (diff.inMinutes < 1) return "Adesso";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min fa";
    if (diff.inHours < 24) return "${diff.inHours} ore fa";
    return "${ts.day}/${ts.month}/${ts.year}";
  }
}