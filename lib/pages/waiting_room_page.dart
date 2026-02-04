import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/logiche/requests/user_request_service.dart';

class WaitingRoomPage extends StatefulWidget {
  const WaitingRoomPage({super.key});

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  bool isLoading = false;

  Future<void> _sendRequest() async {
    setState(() => isLoading = true);

    final success = await UserRequestService.sendAccessRequest();

    setState(() => isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "Richiesta inviata correttamente!"
              : "Errore durante l'invio della richiesta.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: "Tipic.ooo Bar",
      showBack: true,
      scrollable: true,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // ⭐ IMMAGINE
            SizedBox(
              height: 260,
              child: Lottie.asset(
                "assets/lottie/waiting_hero.json",
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 32),

            // ⭐ PULSANTE CON LOGICA
            isLoading
                ? const CircularProgressIndicator(color: Colors.blue)
                : BlueNarrowButton(
                    label: "Invia richiesta di accesso",
                    icon: Icons.send,
                    onPressed: _sendRequest,
                  ),

            const SizedBox(height: 20),

            // ⭐ TESTO SOTTO IL PULSANTE
            const Text(
              "La richiesta dovrà essere approvata,\n"
              "riceverai una notifica quando verificheremo la posizione.\n"
              "Grazie",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: Color(0xFF6F6F6F),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}