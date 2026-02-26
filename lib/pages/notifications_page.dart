import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/theme/app_colors.dart';
import 'package:tipicooo/logiche/requests/office_access_service.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/logiche/requests/user_request_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ⭐ Sistema notifiche
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';
import 'package:tipicooo/hive/hive_register_activity.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/utils/date_format_it.dart';
import 'package:tipicooo/pages/users/staff/manage_staff_page.dart';
import 'package:tipicooo/pages/users/staff/join_staff_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const String _primaryAdminEmail = "carlo.mertolini@gmail.com";
  bool _isOpeningOffice = false;

  Future<void> _refreshNotifications() async {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    // ⭐ Segna tutte le notifiche come lette DOPO il primo frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationController.instance.markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationController.instance.notifications;

    return BasePage(
      headerTitle: "Le tue notifiche",
      onRefresh: _refreshNotifications,
      showBack: true,
      showHome: false,
      showBell: false,
      showProfile: true,
      scrollable: false, // ⭐ Importante per evitare overflow

      body: Stack(
        children: [
          notifications.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Non ci sono notifiche al momento.",
                    style: TextStyle(fontSize: 16, color: AppColors.black),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
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
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) {
                              NotificationController.instance
                                  .deleteNotification(n.id);
                              setState(() {});
                            },
                            child: _buildNotificationTile(n),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          if (_isOpeningOffice)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification n) {
    return InkWell(
      onTap: () => _handleNotificationTap(n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accentYellow.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentYellow),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.notifications,
              color: AppColors.primaryBlue,
              size: 28,
            ),
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
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(AppNotification n) async {
    if (_isOpeningOffice) return;

    if (n.action == "open_user_cashback") {
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.userCashback);
      return;
    }

    if ((n.action ?? "").startsWith("open_activity_payments|")) {
      final requestId = (n.action ?? "").split("|").length > 1
          ? (n.action ?? "").split("|")[1].trim()
          : "";
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.activityPayments,
        arguments: {"activityRequestId": requestId},
      );
      return;
    }

    if (n.action == "open_staff_manage") {
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ManageStaffPage()));
      return;
    }

    if (n.action == "open_staff_join") {
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const JoinStaffPage()));
      return;
    }

    if (n.action == "open_office_admin_requests" ||
        n.action == "open_office_activity_requests" ||
        n.action == "open_office_users" ||
        (n.action ?? "").startsWith("open_office_purchase_pending")) {
      final attrs = await AuthService.instance.getUserAttributes();
      final email = (attrs["email"] ?? "").trim().toLowerCase();
      final isPrimaryAdmin = email == _primaryAdminEmail;
      if (!isPrimaryAdmin) {
        final status = await UserRequestService.getUserStatus();
        final enabled = status["enabled"] == true;
        if (!enabled) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Accesso ufficio non autorizzato. Invia richiesta e attendi approvazione.",
              ),
            ),
          );
          return;
        }
      }

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
      setState(() => _isOpeningOffice = true);
      final code = await OfficeAccessService.requestOfficeCode();
      if (!mounted) return;
      setState(() => _isOpeningOffice = false);
      if (code == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Errore: impossibile aprire l'ufficio."),
          ),
        );
        return;
      }

      String officeUrl = "https://ilpassaparoladicarlo.com/office/?code=$code";
      if (n.action == "open_office_users") {
        officeUrl = "$officeUrl&section=users";
      }
      OfficeAccessService.markOfficeOpenedNow();
      await launchUrl(
        Uri.parse(officeUrl),
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    if (n.action == "open_activity_photos") {
      HiveRegisterActivity.saveField('open_photos', true);
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.registerActivity);
      return;
    }

    if (n.action == "open_register_activity") {
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.registerActivity);
      return;
    }
  }

  String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);

    if (diff.inMinutes < 1) return "Adesso";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min fa";
    if (diff.inHours < 24) return "${diff.inHours} ore fa";
    return DateFormatIt.dateTime(ts);
  }
}
