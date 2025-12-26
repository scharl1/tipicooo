import 'package:flutter/material.dart';
import '../widgets/base_page.dart';
import '../theme/app_colors.dart';
import '../logiche/dashboard/dashboard_controller.dart';

class DashboardUtentePage extends StatefulWidget {
  const DashboardUtentePage({super.key});

  @override
  State<DashboardUtentePage> createState() => _DashboardUtentePageState();
}

class _DashboardUtentePageState extends State<DashboardUtentePage> {
  late DashboardController controller;

  @override
  void initState() {
    super.initState();
    controller = DashboardController(onUpdate: () => setState(() {}));
    controller.loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    final title = controller.userName == null
        ? "Benvenuto/a..."
        : "Benvenuto/a ${controller.userName} nella tua Dashboard";

    return BasePage(
      headerTitle: title,
      showLogout: true,
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // 👋 Saluto utente
                  Text(
                    "Ciao ${controller.userName} 👋",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Questa è la tua Dashboard personale.",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primaryBlue,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 👉 Qui aggiungeremo i widget della dashboard
                ],
              ),
            ),
    );
  }
}