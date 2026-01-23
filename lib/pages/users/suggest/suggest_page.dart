import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';

class SuggestPage extends StatelessWidget {
  const SuggestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: 'Suggerisci',
      showBack: true,
      scrollable: true,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            const Text(
              'Cosa vuoi suggerire?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 30),

            // ⭐ CENTRA TUTTO E PRENDE LA LARGHEZZA DEL PIÙ GRANDE
            Center(
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // 🔵 Pulsante: Suggerisci attività
                    BlueNarrowButton(
                      label: 'Suggerisci attività',
                      icon: Icons.store_mall_directory,
                      onPressed: () {
                        Navigator.pushNamed(context, '/suggest_activity');
                      },
                    ),

                    const SizedBox(height: 20),

                    // 🔵 Pulsante: Suggerisci utente
                    BlueNarrowButton(
                      label: 'Invita con WhatsApp',
                      icon: Icons.person_add_alt_1,
                      onPressed: () {
                        Navigator.pushNamed(context, '/suggest_user');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}