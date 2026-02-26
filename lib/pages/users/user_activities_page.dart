import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/pages/users/staff/manage_staff_page.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

import '../../widgets/base_page.dart';

class UserActivitiesPage extends StatefulWidget {
  const UserActivitiesPage({super.key});

  @override
  State<UserActivitiesPage> createState() => _UserActivitiesPageState();
}

class _UserActivitiesPageState extends State<UserActivitiesPage> {
  bool _loading = true;
  bool _hasOwnedApprovedActivity = false;

  @override
  void initState() {
    super.initState();

    // Se l'utente arriva qui ma non e' loggato (es. sessione scaduta),
    // lo rimandiamo alla Home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!AuthState.isUserLoggedIn) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
      }
    });

    _loadOwnership();
  }

  Future<void> _loadOwnership() async {
    try {
      final activities = await ActivityRequestService.fetchActivitiesForMe();
      final hasOwned = activities.any((it) {
        final status = (it["status"] ?? "").toString();
        if (status != "approved") return false;
        final roleType = (it["roleType"] ?? "").toString().toLowerCase().trim();
        return roleType == "owner";
      });
      if (!mounted) return;
      setState(() {
        _hasOwnedApprovedActivity = hasOwned;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasOwnedApprovedActivity = false;
        _loading = false;
      });
    }
  }

  Future<void> _refreshPage() async {
    await _loadOwnership();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: AuthState.isLoggedIn,
      builder: (context, loggedIn, _) {
        final isLoggedIn = loggedIn == true;
        return BasePage(
          scrollable: true,
          headerTitle: "Le tue attività",
          onRefresh: _refreshPage,
          showBell: isLoggedIn,
          showProfile: isLoggedIn,
          showHome: true,
          showBack: true,
          showLogout: false,
          body: AppBodyLayout(
            children: [
              const SizedBox(height: 10),
              const Text(
                "Da qui puoi gestire la tua attività e i tuoi dipendenti.",
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (!isLoggedIn) ...[
                const Text(
                  "Devi essere loggato per accedere a questa sezione.",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                BlueNarrowButton(
                  label: "Torna alla Home",
                  icon: Icons.home,
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.home,
                      (route) => false,
                    );
                  },
                ),
              ] else ...[
                BlueNarrowButton(
                  label: "Registra/Modifica attività",
                  icon: Icons.store_mall_directory,
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.registerActivity);
                  },
                ),
                const SizedBox(height: 20),
                if (_loading) ...[
                  const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (!_loading && _hasOwnedApprovedActivity) ...[
                  BlueNarrowButton(
                    label: "Dipendenti",
                    icon: Icons.groups_2_outlined,
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ManageStaffPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
