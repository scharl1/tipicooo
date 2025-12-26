import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/app_bottom_nav.dart';
import 'package:tipicooo/theme/app_colors.dart'; // 👈 per usare i colori centralizzati
import 'package:tipicooo/logiche/navigation/app_routes.dart'; // 👈 per la rotta TestPage

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: "Tipic.ooo",
      showBack: false,
      showHome: false,
      showBell: true,
      bottomNavigationBar: const AppBottomNav(currentIndex: -1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Benvenuto in Tipic.ooo, siamo in contiua evoluzione, se trovi Bug suggerisciceli, Grazie!",
              style: TextStyle(
                fontSize: 24,                // ✅ dimensione testo
                fontWeight: FontWeight.bold, // ✅ grassetto
                color: AppColors.black,      // ✅ colore centralizzato
              ),
              textAlign: TextAlign.center,   // ✅ centrato
            ),
            const SizedBox(height: 20), // spazio tra testo e pulsante
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentYellow, // 👈 colore giallo dal tuo file
              ),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.testPage); // 👈 naviga alla TestPage
              },
              child: const Text(
                "Vai al Test",
                style: TextStyle(
                  color: AppColors.black, // 👈 testo nero dal tuo file
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}