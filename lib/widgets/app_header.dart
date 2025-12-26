import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../logiche/navigation/header_routes.dart';
import '../logiche/notifications/notification_state.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBell;
  final bool showBack;
  final bool showHome;
  final bool showLogout;
  final bool showProfile;

  const AppHeader({
    super.key,
    required this.title,
    this.showBell = true,
    this.showBack = false,
    this.showHome = false,
    this.showLogout = false,
    this.showProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primaryBlue,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,

      // 🔵 ICONA A SINISTRA (Back o Home)
      leading: showBack
          ? IconButton(
              icon: const Icon(AppIcons.back, color: AppColors.white),
              onPressed: () => Navigator.pop(context),
            )
          : showHome
              ? IconButton(
                  icon: const Icon(AppIcons.home, color: AppColors.white),
                  onPressed: () => HeaderRoutes.navigateToHome(context),
                )
              : null,

      // 🔵 TITOLO
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
        ),
      ),

      // 🔵 ICONE A DESTRA
      actions: [
        if (showProfile)
          IconButton(
            icon: const Icon(AppIcons.user, color: AppColors.white),
            onPressed: () => HeaderRoutes.goToProfile(context),
          ),

        if (showBell)
          ValueListenableBuilder<bool>(
            valueListenable: NotificationState.hasUnread,
            builder: (context, hasUnread, _) {
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

        if (showLogout)
          IconButton(
            icon: const Icon(AppIcons.logout, color: AppColors.white),
            onPressed: () => HeaderRoutes.logout(context),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}