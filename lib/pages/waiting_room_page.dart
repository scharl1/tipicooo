// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/logiche/requests/user_request_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';

class WaitingRoomPage extends StatefulWidget {
  const WaitingRoomPage({super.key});

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  bool isLoading = false;
  bool isPending = false;

  static const String _pendingKey = "office_request_pending";
  static const String _lastRequestedKey = "office_request_last_requested";

  @override
  void initState() {
    super.initState();
    _loadPendingState();
  }

  Future<void> _loadPendingState() async {
    try {
      // Aggiorna lo stato dal backend per essere sicuri
      final status = await UserRequestService.getUserStatus();
      final requested = status["requested"] == true;

      // Se il backend dice che non c'è richiesta, pulisci i flag locali
      if (!requested) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_pendingKey, false);
        await prefs.setBool(_lastRequestedKey, false);
      }

      if (!mounted) return;
      setState(() {
        isPending = requested;
      });
    } catch (_) {
      // Fallback: non bloccare l'invio se non riusciamo a leggere lo status
      if (!mounted) return;
      setState(() {
        isPending = false;
      });
    }
  }

  Future<void> _sendRequest() async {
    if (isPending) return;
    setState(() => isLoading = true);

    final success = await UserRequestService.sendAccessRequest();

    setState(() => isLoading = false);

    if (success) {
      // ⭐ CREA NOTIFICA
      NotificationController.instance.addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: "Richiesta inviata",
          message:
              "La tua richiesta di accesso a Tipic.ooo Office è in attesa di approvazione.",
          timestamp: DateTime.now(),
        ),
      );
      setState(() {
        isPending = true;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "Richiesta inviata correttamente!"
              : "Errore durante l'invio della richiesta.",
        ),
      ),
    );

    if (success) {
      // ⭐ TORNA ALLA HOME
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  Future<void> _cancelRequest() async {
    setState(() => isLoading = true);
    final ok = await UserRequestService.deleteUserRequests();
    setState(() => isLoading = false);

    if (ok) {
      setState(() {
        isPending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Richiesta annullata.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore annullamento richiesta.")),
      );
    }
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
                isPending
                    ? "assets/lottie/traffic_red.json"
                    : "assets/lottie/waiting_hero.json",
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 32),

            // ⭐ PULSANTE CON LOGICA
            if (isLoading)
              const CircularProgressIndicator(color: Colors.blue)
            else if (!isPending)
              BlueNarrowButton(
                label: "Invia richiesta di accesso",
                icon: Icons.send,
                onPressed: _sendRequest,
              )
            else
              DangerButton(
                label: "Annulla richiesta",
                icon: Icons.cancel,
                onPressed: _cancelRequest,
              ),

            const SizedBox(height: 20),

            // ⭐ TESTO SOTTO IL PULSANTE
            Text(
              isPending
                  ? "La tua richiesta è in attesa di approvazione.\n"
                      "Ti avviseremo quando ci saranno aggiornamenti."
                  : "La richiesta dovrà essere approvata,\n"
                      "riceverai una notifica quando verificheremo la posizione.\n"
                      "Grazie",
              textAlign: TextAlign.center,
              style: const TextStyle(
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
