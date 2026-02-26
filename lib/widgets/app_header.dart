import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../logiche/navigation/header_routes.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  final VoidCallback? onBackPressed;

  const AppHeader({
    super.key,
    required this.title,
    this.showBell = true,
    this.showBack = false,
    this.showHome = false,
    this.showLogout = false,
    this.showProfile = false,
    this.onLogout,
    this.onBackPressed,
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
    final canGoBack = Navigator.canPop(context);
    final shouldShowBack = showBack || (!showHome && canGoBack);

    if (shouldShowBack) {
      return IconButton(
        icon: const Icon(AppIcons.back, color: AppColors.white),
        onPressed: () {
          if (onBackPressed != null) {
            onBackPressed!();
            return;
          }
          // Se può tornare indietro torna indietro, altrimenti va in Home.
          if (canGoBack) {
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
        _buildProfileIconButton(context, loggedIn),
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

  Widget _buildProfileIconButton(BuildContext context, bool loggedIn) {
    void onTap() {
      if (loggedIn) {
        HeaderRoutes.goToUserPage(context);
      } else {
        HeaderRoutes.goToProfile(context);
      }
    }

    if (!loggedIn) {
      return IconButton(
        icon: const Icon(AppIcons.user, color: AppColors.white),
        onPressed: onTap,
      );
    }

    if (!Hive.isBoxOpen('profile')) {
      return IconButton(
        icon: const Icon(AppIcons.user, color: AppColors.white),
        onPressed: onTap,
      );
    }

    final box = Hive.box('profile');
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, _, __) {
        final b64 = (box.get('avatar_bytes_b64') ?? "").toString().trim();
        final rawBytes = box.get('avatar_bytes');
        final localPath = (box.get('avatar_local_path') ?? "")
            .toString()
            .trim();

        Widget fallbackIcon() => IconButton(
              icon: const Icon(AppIcons.user, color: AppColors.white),
              onPressed: onTap,
            );

        Widget wrapAvatar(Widget child) => IconButton(
              onPressed: onTap,
              icon: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            );

        if (rawBytes is Uint8List && rawBytes.isNotEmpty) {
          return wrapAvatar(
            Image.memory(
              rawBytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  const Icon(AppIcons.user, color: AppColors.white, size: 20),
            ),
          );
        }

        if (rawBytes is List && rawBytes.isNotEmpty) {
          try {
            final bytes = Uint8List.fromList(
              rawBytes.map((e) => (e as num).toInt()).toList(),
            );
            return wrapAvatar(
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const Icon(
                  AppIcons.user,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            );
          } catch (_) {}
        }

        if (b64.isNotEmpty) {
          try {
            final bytes = base64Decode(b64);
            return wrapAvatar(
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
                    const Icon(AppIcons.user, color: AppColors.white, size: 20),
              ),
            );
          } catch (_) {}
        }

        if (!kIsWeb && localPath.isNotEmpty) {
          return wrapAvatar(
            Image.file(
              File(localPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(AppIcons.user, color: AppColors.white, size: 20),
            ),
          );
        }

        return fallbackIcon();
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
