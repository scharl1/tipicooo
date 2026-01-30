import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/base_page.dart';

class WaitingRoomPage extends StatelessWidget {
  final WaitingRoomStatus status;

  const WaitingRoomPage({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return BasePage(
      title: "Tipic.ooo Bar",
      showBackButton: true, // ← usa la tua icona back in app_header.dart
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // -----------------------------
            // HERO SECTION (salottino)
            // -----------------------------
            Center(
              child: SizedBox(
                height: 260,
                child: Image.asset(
                  "assets/images/waiting_room_hero.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // -----------------------------
            // STATUS SECTION (semaforo + titolo)
            // -----------------------------
            Center(
              child: Column(
                children: [
                  _buildTrafficLight(status),
                  const SizedBox(height: 16),
                  Text(
                    _buildTitle(status),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _buildTitleColor(status),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // -----------------------------
            // DESCRIPTION SECTION
            // -----------------------------
            Text(
              _buildDescription(status),
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

  // ---------------------------------------------------------
  // WIDGET SEMAFORO
  // ---------------------------------------------------------
  Widget _buildTrafficLight(WaitingRoomStatus status) {
    switch (status) {
      case WaitingRoomStatus.pending:
        return Image.asset(
          "assets/images/traffic_yellow.png",
          height: 90,
        );

      case WaitingRoomStatus.rejected:
        return Image.asset(
          "assets/images/traffic_red.png",
          height: 90,
        );
    }
  }

  // ---------------------------------------------------------
  // TITOLO
  // ---------------------------------------------------------
  String _buildTitle(WaitingRoomStatus status) {
    switch (status) {
      case WaitingRoomStatus.pending:
        return "Richiesta in attesa";
      case WaitingRoomStatus.rejected:
        return "Richiesta respinta";
    }
  }

  // ---------------------------------------------------------
  // COLORE TITOLO
  // ---------------------------------------------------------
  Color _buildTitleColor(WaitingRoomStatus status) {
    switch (status) {
      case WaitingRoomStatus.pending:
        return const Color(0xFFF4A300); // giallo
      case WaitingRoomStatus.rejected:
        return const Color(0xFFD32F2F); // rosso
    }
  }

  // ---------------------------------------------------------
  // DESCRIZIONE
  // ---------------------------------------------------------
  String _buildDescription(WaitingRoomStatus status) {
    switch (status) {
      case WaitingRoomStatus.pending:
        return "La tua richiesta è stata inviata.\nIl nostro staff la sta valutando.";
      case WaitingRoomStatus.rejected:
        return "La tua richiesta non è stata approvata.\nPer maggiori informazioni contatta il nostro staff.";
    }
  }
}

// ---------------------------------------------------------
// ENUM STATO
// ---------------------------------------------------------
enum WaitingRoomStatus {
  pending,
  rejected,
}