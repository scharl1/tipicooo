import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../logiche/navigation/header_routes.dart';

// ⭐ Nuovo sistema notifiche
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';

/// Header universale dell’app.
/// Gestisce titolo, icone e navigazione in modo coerente.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBell;
  final bool showBack;
  final bool showHome;
  final bool showLogout;
  final bool showProfile;

  // ⭐ Callback esterna per il logout
  final VoidCallback? onLogout;

  const AppHeader({
    super.key,
    required this.title,
    this.showBell = true,
    this.showBack = false,
    this.showHome = false,
    this.showLogout = false,
    this.showProfile = false,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primaryBlue,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,

      leading: _buildLeftIcon(context),

      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
        ),
      ),

      actions: _buildRightIcons(context),
    );
  }

  /// Costruisce l’icona a sinistra (Back o Home)
  Widget? _buildLeftIcon(BuildContext context) {
    if (showBack) {
      return IconButton(
        icon: const Icon(AppIcons.back, color: AppColors.white),
        onPressed: () {
          // ⭐ Comportamento corretto:
          // - Se può tornare indietro → torna indietro
          // - Altrimenti → vai alla Home
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            HeaderRoutes.navigateToHome(context);
          }
        },
      );
    }

    if (showHome) {
      return IconButton(
        icon: const Icon(AppIcons.home, color: AppColors.white),
        onPressed: () => HeaderRoutes.navigateToHome(context),
      );
    }

    return null;
  }

  /// Costruisce le icone a destra (Profilo, Notifiche, Logout)
  List<Widget> _buildRightIcons(BuildContext context) {
    final List<Widget> icons = [];
    final loggedIn = AuthState.isLoggedIn.value;

    if (showProfile) {
      icons.add(
        IconButton(
          icon: const Icon(AppIcons.user, color: AppColors.white),
          onPressed: () {
            if (loggedIn) {
              HeaderRoutes.goToUserPage(context);
            } else {
              HeaderRoutes.goToProfile(context);
            }
          },
        ),
      );
    }

    if (showBell) {
      icons.add(
        AnimatedBuilder(
          animation: NotificationController.instance,
          builder: (context, _) {
            final hasUnread = NotificationController.instance.hasUnread;

            return Stack(
              children: [
                IconButton(
                  icon: const Icon(AppIcons.bell, color: AppColors.white),
                  onPressed: () => HeaderRoutes.goToNotifications(context),
                ),
                if (hasUnread)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    if (showLogout) {
      icons.add(
        IconButton(
          icon: const Icon(AppIcons.logout, color: AppColors.white),
          onPressed: onLogout,
        ),
      );
    }

    return icons;
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}