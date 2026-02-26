import 'package:flutter/material.dart';
import 'package:tipicooo_office/pages/activities/activity_movements_page.dart';
import 'package:tipicooo_office/pages/activities/activity_rejected_payments_page.dart';

class ActivityApprovedDetailPage extends StatelessWidget {
  const ActivityApprovedDetailPage({super.key, required this.activity});

  final Map<String, dynamic> activity;

  String _field(String key) => (activity[key] ?? "").toString();

  String _title() {
    final insegna = _field("insegna").trim();
    final ragione = _field("ragione_sociale").trim();
    if (insegna.isNotEmpty) return insegna;
    if (ragione.isNotEmpty) return ragione;
    return _field("requestId").trim().isEmpty
        ? "Attività"
        : _field("requestId").trim();
  }

  @override
  Widget build(BuildContext context) {
    final requestId = _field("requestId").trim();
    final email = _field("email").trim();
    final tipo = _field("tipo_attivita").trim();

    return Scaffold(
      appBar: AppBar(title: Text(_title())),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (tipo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  tipo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ),
            const Text(
              "Dettaglio attività",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _row("Insegna", _field("insegna")),
            _row("Ragione sociale", _field("ragione_sociale")),
            _row("Email", email),
            _row("Telefono", _field("telefono")),
            _row("Città", _field("citta")),
            _row("Provincia", _field("provincia")),
            _row("CAP", _field("cap")),
            _row("Via", _field("via")),
            _row("Numero civico", _field("numero_civico")),
            if (requestId.isNotEmpty) _row("ID attività", requestId),
            const SizedBox(height: 18),
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.green.shade700, width: 1.8),
              ),
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text("Pagamenti accettati"),
                subtitle: const Text(
                  "Apri i movimenti del mese e verifica i pagamenti confermati.",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: requestId.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ActivityMovementsPage(
                              activityRequestId: requestId,
                              activityEmail: email,
                              activityName: _title(),
                            ),
                          ),
                        );
                      },
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.red.shade700, width: 1.8),
              ),
              child: ListTile(
                leading: const Icon(Icons.cancel_schedule_send_outlined),
                title: const Text("Pagamenti rifiutati"),
                subtitle: const Text(
                  "Apri l’elenco dei pagamenti rifiutati per questa attività.",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: requestId.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ActivityRejectedPaymentsPage(
                              activityRequestId: requestId,
                              activityEmail: email,
                              activityName: _title(),
                            ),
                          ),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    final v = value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(v.isEmpty ? "-" : v)),
        ],
      ),
    );
  }
}
