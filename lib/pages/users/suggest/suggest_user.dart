import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class SuggestUserPage extends StatelessWidget {
  final String userId;

  const SuggestUserPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final referralLink =
        "https://ilpassaparoladicarlo.com/benvenuti-in-tipic-ooo/?ref=$userId";

    return BasePage(
      headerTitle: "Invita con WhatsApp",
      showBack: true,
      scrollable: true,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Invia il tuo link personale ai tuoi contatti su WhatsApp.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 30),

            // 🔵 Link personale
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                referralLink,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),

            const SizedBox(height: 20),

            // 🔵 Bottone WhatsApp
            BlueNarrowButton(
              label: "Invita via WhatsApp",
              icon: Icons.share, // ← icona compatibile
              onPressed: () async {
                final message =
                    "Ciao! Scarica Tipicooo da qui:\n$referralLink\n\nQuando ti registri, entri automaticamente nella mia rete.";

                final Uri url = Uri.parse(
                    "https://wa.me/?text=${Uri.encodeComponent(message)}");

                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),

            const SizedBox(height: 20),

            // 🔵 Bottone copia link
            BlueNarrowButton(
              label: "Copia link",
              icon: Icons.copy,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: referralLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Link copiato")),
                );
              },
            ),

            const SizedBox(height: 40),

            const Text(
              "I tuoi suggerimenti",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 20),

            // 🔵 Lista suggerimenti (placeholder)
            _buildSuggestionList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionList() {
    // TODO: sostituire con dati reali da DynamoDB
    final suggestions = [
      {"email": "mario@gmail.com", "status": "inviato"},
      {"email": "luca@gmail.com", "status": "in_attesa"},
      {"email": "anna@gmail.com", "status": "registrato"},
    ];

    Color statusColor(String status) {
      switch (status) {
        case "inviato":
          return Colors.red;
        case "in_attesa":
          return Colors.yellow;
        case "registrato":
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

    return Column(
      children: suggestions.map((s) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor(s["status"]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            s["email"]!,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}