import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_colors.dart';
import '../logiche/auth/auth_state.dart';
import '../logiche/navigation/app_routes.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({
    super.key,
    this.currentIndex = 0,
  });

  void _onTap(BuildContext context, int index, bool loggedIn) {
    // Se siamo in Home (currentIndex = -1), NON blocchiamo mai il tap
    if (currentIndex != -1 && index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, "/search");
        break;

      case 1:
        Navigator.pushReplacementNamed(context, "/favorites");
        break;

      case 2:
        if (loggedIn) {
          Navigator.pushReplacementNamed(context, AppRoutes.user);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.profile);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthState.isLoggedIn,
      builder: (context, loggedIn, _) {
        // ⭐ Se currentIndex = -1 (Home), usiamo 0 per evitare crash
        final safeIndex = currentIndex == -1 ? 0 : currentIndex;
        return BottomNavigationBar(
          currentIndex: safeIndex,
          backgroundColor: AppColors.white,

          // ⭐ Se siamo in Home, nessuna icona deve sembrare attiva
          selectedItemColor:
              currentIndex == -1 ? Colors.grey : AppColors.primaryBlue,

          unselectedItemColor: Colors.grey,

          onTap: (index) => _onTap(context, index, loggedIn),

          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              label: 'Cerca',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              label: 'Preferiti',
            ),
            BottomNavigationBarItem(
              icon: _profileIconFromHiveReactive(loggedIn),
              label: 'Profilo',
            ),
          ],
        );
      },
    );
  }

  Widget _profileIconFromHiveReactive(bool loggedIn) {
    if (!loggedIn) {
      return const Icon(Icons.person_outline);
    }

    if (!Hive.isBoxOpen('profile')) {
      return const Icon(Icons.person_outline);
    }
    final box = Hive.box('profile');
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, _, __) {
        return _profileIconFromHive(box);
      },
    );
  }

  Widget _profileIconFromHive(Box box) {
    try {
      final rawBytes = box.get('avatar_bytes');
      if (rawBytes is Uint8List && rawBytes.isNotEmpty) {
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(
            rawBytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const Icon(Icons.person_outline),
          ),
        );
      }
      if (rawBytes is List && rawBytes.isNotEmpty) {
        try {
          final bytes = Uint8List.fromList(
            rawBytes.map((e) => (e as num).toInt()).toList(),
          );
          return Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_outline),
            ),
          );
        } catch (_) {}
      }

      final b64 = (box.get('avatar_bytes_b64') ?? "").toString().trim();
      final localPath = (box.get('avatar_local_path') ?? "").toString().trim();

      if (b64.isNotEmpty) {
        try {
          final bytes = base64Decode(b64);
          return Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_outline),
            ),
          );
        } catch (_) {}
      }

      if (!kIsWeb && localPath.isNotEmpty) {
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(localPath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.person_outline),
          ),
        );
      }
      return const Icon(Icons.person_outline);
    } catch (_) {
      return const Icon(Icons.person_outline);
    }
  }
}
