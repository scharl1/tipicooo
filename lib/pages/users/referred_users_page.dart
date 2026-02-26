import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/requests/purchase_service.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

class ReferredUsersPage extends StatefulWidget {
  const ReferredUsersPage({super.key});

  @override
  State<ReferredUsersPage> createState() => _ReferredUsersPageState();
}

class _ReferredUsersPageState extends State<ReferredUsersPage> {
  late Future<Map<String, dynamic>?> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = PurchaseService.fetchMySummary();
  }

  Future<void> _refreshPage() async {
    setState(() {
      _summaryFuture = PurchaseService.fetchMySummary();
    });
    await _summaryFuture;
  }

  num _firstNum(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return 0;
    for (final k in keys) {
      final v = data[k];
      if (v is num) return v;
      if (v is String) {
        final n = num.tryParse(v.trim());
        if (n != null) return n;
      }
    }
    return 0;
  }

  String _fmtEuroFromCents(num value) {
    final cents = value.toInt();
    final sign = cents < 0 ? "-" : "";
    final abs = cents.abs();
    final euro = abs ~/ 100;
    final cent = abs % 100;
    return "$sign$euro,${cent.toString().padLeft(2, '0')}";
  }

  List<Map<String, dynamic>> _extractReferredUsers(Map<String, dynamic>? data) {
    if (data == null) return const <Map<String, dynamic>>[];
    final raw = data["referredUsers"] ?? data["invitedUsers"] ?? data["invitees"];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .where((u) {
          final email = (u["email"] ?? u["requesterEmail"] ?? u["inviteeEmail"] ?? "")
              .toString()
              .trim()
              .toLowerCase();
          return email.isNotEmpty && email.contains("@");
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: false,
      headerTitle: "I tuoi suggeriti",
      onRefresh: _refreshPage,
      showBack: true,
      showHome: true,
      showProfile: true,
      showBell: false,
      showLogout: false,
      body: AppBodyLayout(
        children: [
          const Text(
            "I tuoi suggeriti",
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>?>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text(
                  "Caricamento...",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                );
              }
              final data = snapshot.data;
              if (data == null) {
                return const Text(
                  "Dati non disponibili.",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                );
              }

              final referredUsersCount = _firstNum(data, const [
                "referredUsersCount",
                "linkedInvitesCount",
                "invitedUsersCount",
              ]).toInt();
              final referredOps = _firstNum(data, const [
                "referredConfirmedCount",
                "invitedConfirmedCount",
                "referrerConfirmedCount",
              ]).toInt();
              final referredSpentCents = _firstNum(data, const [
                "referredTotalSpentCents",
                "invitedTotalSpentCents",
              ]);
              final referrerCents = _firstNum(data, const [
                "totalReferrerCashbackCents",
                "referrerCashbackCents",
              ]);
              final users = _extractReferredUsers(data);

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F6EF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE7C26A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Inviti collegati: $referredUsersCount",
                          style: AppTextStyles.body,
                        ),
                        Text(
                          "Operazioni confermate invitati: $referredOps",
                          style: AppTextStyles.body,
                        ),
                        Text(
                          "Totale speso invitati: € ${_fmtEuroFromCents(referredSpentCents)}",
                          style: AppTextStyles.body,
                        ),
                        Text(
                          "Cashback maturato da inviti: € ${_fmtEuroFromCents(referrerCents)}",
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (users.isEmpty)
                    const Text(
                      "Nessun invitato registrato trovato al momento.",
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    )
                  else
                    Column(
                      children: users.map((u) {
                        final email = (u["email"] ??
                                u["requesterEmail"] ??
                                u["inviteeEmail"] ??
                                "")
                            .toString()
                            .trim();
                        final cashbackCents = _firstNum(u, const [
                          "referrerCashbackCents",
                          "cashbackCents",
                        ]);

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Invitato: ${email.isNotEmpty ? email : "N/D"}",
                                style: AppTextStyles.pageMessage,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Totale che sta generando: € ${_fmtEuroFromCents(cashbackCents)}",
                                style: AppTextStyles.body,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
