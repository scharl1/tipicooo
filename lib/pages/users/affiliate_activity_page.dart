import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/logiche/requests/collaborator_request_service.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

class AffiliateActivityPage extends StatefulWidget {
  const AffiliateActivityPage({super.key});

  @override
  State<AffiliateActivityPage> createState() => _AffiliateActivityPageState();
}

class _AffiliateActivityPageState extends State<AffiliateActivityPage> {
  bool _loadingStatus = true;
  bool _sendingRequest = false;
  bool _endpointAvailable = true;
  bool _requested = false;
  bool _enabled = false;

  final List<_LeadActivity> _items = const [
    _LeadActivity(
      businessName: "Trattoria La Quercia",
      city: "Parma",
      status: "invoice_paid",
      monthlyValueEur: 200,
      payoutEur: 25,
    ),
    _LeadActivity(
      businessName: "Bar Centrale",
      city: "Cremona",
      status: "invoice_sent",
      monthlyValueEur: 200,
      payoutEur: 20,
    ),
    _LeadActivity(
      businessName: "Gommista 44 Gatti",
      city: "Brescia",
      status: "pending_46_days",
      monthlyValueEur: 200,
      payoutEur: 30,
    ),
  ];

  int get _validMonthlyActivities => _items.length;

  int get _totalPayableEur => _items
      .where((e) => e.status == "invoice_paid")
      .fold<int>(0, (sum, e) => sum + e.payoutEur);

  String get _currentTierLabel {
    final n = _validMonthlyActivities;
    if (n >= 20) return "Tier 3 • 15% (€30/attività)";
    if (n >= 16) return "Tier 2 • 12,5% (€25/attività)";
    if (n >= 12) return "Tier 1 • 10% (€20/attività)";
    return "Sotto soglia tier";
  }

  Color _statusColor(String status) {
    switch (status) {
      case "invoice_paid":
        return const Color(0xFF1D9B4E);
      case "invoice_sent":
        return const Color(0xFF0B5ED7);
      default:
        return const Color(0xFFF08C00);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCollaboratorStatus();
  }

  Future<void> _loadCollaboratorStatus() async {
    final status = await CollaboratorRequestService.getStatus();
    if (!mounted) return;
    setState(() {
      _loadingStatus = false;
      _endpointAvailable = status["available"] != false;
      _requested = status["requested"] == true;
      _enabled = status["enabled"] == true;
    });
  }

  Future<void> _sendCollaboratorRequest() async {
    if (_sendingRequest) return;
    setState(() => _sendingRequest = true);
    final ok = await CollaboratorRequestService.sendRequest();
    if (!mounted) return;
    setState(() => _sendingRequest = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Richiesta non inviata. Endpoint non disponibile o errore rete.",
          ),
        ),
      );
      return;
    }
    await _loadCollaboratorStatus();
  }

  String _statusText(String status) {
    switch (status) {
      case "invoice_paid":
        return "Liquidabile";
      case "invoice_sent":
        return "Fattura inviata";
      default:
        return "In attesa 46 giorni";
    }
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: true,
      headerTitle: "Affilia attività",
      showBack: true,
      showHome: true,
      showProfile: true,
      showBell: true,
      showLogout: false,
      body: AppBodyLayout(
        children: [
          const SizedBox(height: 10),
          const Text(
            "Fai crescere Tipic.ooo",
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const Text(
            "Ricevi cashback sulle attività affiliate valide che generano incassi reali, di qualsiasi tipologia.",
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: _loadingStatus
                ? const Text("Verifica stato collaboratore...")
                : !_endpointAvailable
                ? const Text(
                    "Flusso collaboratore in attivazione lato server.",
                    style: AppTextStyles.body,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _enabled
                            ? "Stato collaboratore: approvato"
                            : (_requested
                                  ? "Stato collaboratore: richiesta in attesa"
                                  : "Stato collaboratore: non richiesto"),
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 8),
                      if (!_enabled)
                        BlueNarrowButton(
                          label: _sendingRequest
                              ? "Invio richiesta..."
                              : (_requested
                                    ? "Aggiorna stato richiesta"
                                    : "Richiedi accesso collaboratore"),
                          icon: _requested
                              ? Icons.refresh
                              : Icons.person_add_alt_1_outlined,
                          onPressed: _sendingRequest
                              ? () {}
                              : (_requested
                                    ? _loadCollaboratorStatus
                                    : _sendCollaboratorRequest),
                        ),
                    ],
                  ),
          ),
          if (!_enabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: const Text(
                "Sezione collaboratore disponibile solo dopo autorizzazione.",
                style: AppTextStyles.body,
              ),
            ),
          if (_enabled) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6EF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7C26A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tier corrente: $_currentTierLabel",
                  style: AppTextStyles.pageMessage.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Scala provvigionale: 10% → 12,5% → 15%",
                  style: AppTextStyles.body,
                ),
                const Text(
                  "Valore attività: € 200",
                  style: AppTextStyles.body,
                ),
                const Text(
                  "Valido per tutte le tipologie di attività affiliate.",
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: "Attività valide",
                  value: "$_validMonthlyActivities",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: "Liquidabile",
                  value: "€ $_totalPayableEur",
                ),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Regole operative",
                  style: AppTextStyles.pageMessage,
                ),
                SizedBox(height: 8),
                _RuleRow(text: "Soglia minima: 3 attività a settimana."),
                _RuleRow(text: "Sotto soglia: €10/attività."),
                _RuleRow(
                  text:
                      "Pagamento agente solo dopo prima fattura pagata dell’attività.",
                ),
                _RuleRow(
                  text:
                      "Stati: in attesa 46 giorni → fattura inviata → liquidabile.",
                ),
              ],
            ),
          ),
          BlueNarrowButton(
            label: "Segnala un'attività",
            icon: Icons.store_mall_directory_outlined,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.suggestActivity);
            },
          ),
          BlueNarrowButton(
            label: "Invita un referente",
            icon: Icons.person_add_alt_1_outlined,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.suggestUser);
            },
          ),
          BlueNarrowButton(
            label: "Apri suggerimenti",
            icon: Icons.lightbulb_outline,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.suggest);
            },
          ),
          BlueNarrowButton(
            label: "Stato attività affiliate",
            icon: Icons.fact_check_outlined,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.affiliateActivityStatus);
            },
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Attività affiliate",
                  style: AppTextStyles.pageMessage,
                ),
                const SizedBox(height: 10),
                for (final it in _items)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                it.businessName,
                                style: AppTextStyles.pageMessage.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(it.status).withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _statusColor(it.status),
                                ),
                              ),
                              child: Text(
                                _statusText(it.status),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor(it.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text("Città: ${it.city}", style: AppTextStyles.body),
                        Text(
                          "Valore attività: € ${it.monthlyValueEur}",
                          style: AppTextStyles.body,
                        ),
                        Text(
                          "Provvigione: € ${it.payoutEur}",
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.body),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.pageMessage.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _LeadActivity {
  const _LeadActivity({
    required this.businessName,
    required this.city,
    required this.status,
    required this.monthlyValueEur,
    required this.payoutEur,
  });

  final String businessName;
  final String city;
  final String status;
  final int monthlyValueEur;
  final int payoutEur;
}
