import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';
import 'package:tipicooo/logiche/requests/purchase_service.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/pages/users/referred_users_page.dart';
import 'package:tipicooo/pages/users/purchase_review_page.dart';

class UserCashbackPage extends StatefulWidget {
  const UserCashbackPage({super.key});

  @override
  State<UserCashbackPage> createState() => _UserCashbackPageState();
}

class _UserCashbackPageState extends State<UserCashbackPage> {
  late Future<Map<String, dynamic>?> _summaryFuture;
  late Future<List<Map<String, dynamic>>> _purchasesFuture;
  bool _showReminderBanner = true;
  Timer? _bannerTimer;
  final Set<String> _expandedMonths = <String>{};

  @override
  void initState() {
    super.initState();
    _summaryFuture = PurchaseService.fetchMySummary();
    _purchasesFuture = _loadPurchasesEnriched(limit: 20);
    _bannerTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() => _showReminderBanner = false);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPage() async {
    setState(() {
      _summaryFuture = PurchaseService.fetchMySummary();
      _purchasesFuture = _loadPurchasesEnriched(limit: 20);
    });
    await _summaryFuture;
    await _purchasesFuture;
  }

  String _fmtEuroFromCents(num value) {
    final cents = value.toInt();
    final sign = cents < 0 ? "-" : "";
    final abs = cents.abs();
    final euro = abs ~/ 100;
    final cent = abs % 100;
    return "$sign$euro,${cent.toString().padLeft(2, '0')}";
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

  DateTime? _parseCreatedAt(Map<String, dynamic> it) {
    final raw =
        (it["createdAt"] ??
                it["created_at"] ??
                it["requestedAt"] ??
                it["requestAt"] ??
                "")
            .toString()
            .trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _monthKey(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    return "$y-$m";
  }

  String _monthLabelFromKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final y = parts[0];
    final m = int.tryParse(parts[1]) ?? 1;
    const months = <String>[
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];
    final idx = (m >= 1 && m <= 12) ? (m - 1) : 0;
    return "${months[idx]} $y";
  }

  Future<List<Map<String, dynamic>>> _loadPurchasesEnriched({
    int limit = 20,
  }) async {
    final purchases = await PurchaseService.fetchMyPurchases(limit: limit);
    if (purchases.isEmpty) return purchases;

    try {
      final activities = await ActivityRequestService.fetchApprovedActivitiesPublic();
      final byRequestId = <String, Map<String, dynamic>>{};
      for (final a in activities) {
        final rid = (a["requestId"] ?? a["id"] ?? "").toString().trim();
        if (rid.isEmpty) continue;
        byRequestId[rid] = a;
      }

      return purchases.map((it) {
        final out = Map<String, dynamic>.from(it);
        final rid = (out["activityRequestId"] ?? "").toString().trim();
        if (rid.isEmpty) return out;

        final a = byRequestId[rid];
        if (a == null) return out;

        final name = (a["insegna"] ?? a["activityName"] ?? a["title"] ?? "")
            .toString()
            .trim();
        final country = (a["paese"] ?? a["country"] ?? "").toString().trim();
        final activityType =
            (a["tipo_attivita"] ??
                    a["typeLabel"] ??
                    a["activityType"] ??
                    a["tipoAttivita"] ??
                    "")
                .toString()
                .trim();

        if ((out["activityName"] ?? "").toString().trim().isEmpty &&
            name.isNotEmpty) {
          out["activityName"] = name;
        }
        if ((out["country"] ?? out["paese"] ?? "").toString().trim().isEmpty &&
            country.isNotEmpty) {
          out["country"] = country;
        }
        if ((out["activityType"] ?? out["tipo_attivita"] ?? "")
                .toString()
                .trim()
                .isEmpty &&
            activityType.isNotEmpty) {
          out["activityType"] = activityType;
        }
        return out;
      }).toList();
    } catch (_) {
      return purchases;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: false,
      headerTitle: "I tuoi cashback",
      onRefresh: _refreshPage,
      showBack: true,
      showHome: true,
      showProfile: true,
      showBell: false,
      showLogout: false,
      body: AppBodyLayout(
        children: [
          const Text(
            "I tuoi cashback",
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              );
            },
            child: !_showReminderBanner
                ? const SizedBox.shrink()
                : GestureDetector(
                    key: const ValueKey("cashback_reminder_banner"),
                    onTap: () {
                      _bannerTimer?.cancel();
                      setState(() => _showReminderBanner = false);
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0B5ED7), Color(0xFF1AA7EC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.campaign_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Ricorda, puoi richiedere il caschback al raggiungimento della soglia minima di € 50,00.",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>?>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text(
                  "Caricamento...",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                );
              }
              if (data == null) {
                return const Text(
                  "Sezione in arrivo.",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                );
              }

              final confirmedCount = (data["confirmedCount"] ?? 0) as num;
              final totalUserCashbackCents =
                  (data["totalUserCashbackCents"] ?? 0) as num;
              final referrerPercent = _firstNum(data, const [
                "referrerCashbackPercent",
                "referrerPercent",
                "referrerSharePercent",
              ]);
              final referredUsersCount = _firstNum(data, const [
                "referredUsersCount",
                "linkedInvitesCount",
                "invitedUsersCount",
              ]);
              final referredOps = _firstNum(data, const [
                "referredConfirmedCount",
                "invitedConfirmedCount",
                "referrerConfirmedCount",
              ]);
              final referredSpentCents = _firstNum(data, const [
                "referredTotalSpentCents",
                "invitedTotalSpentCents",
              ]);
              final referrerCents = _firstNum(data, const [
                "totalReferrerCashbackCents",
                "referrerCashbackCents",
              ]);
              final shownPercent = referrerPercent > 0 ? referrerPercent : 3;

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
                          "Totale cashback accumulato: € ${_fmtEuroFromCents(totalUserCashbackCents)}",
                          style: AppTextStyles.body,
                        ),
                        Text(
                          "Transazioni confermate: ${confirmedCount.toInt()}",
                          style: AppTextStyles.body,
                        ),
                        const Text(
                          "Nota: gli accrediti sono arrotondati a 0,10 €.",
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Cashback inviti: ${shownPercent.toStringAsFixed(shownPercent % 1 == 0 ? 0 : 1)}%",
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Inviti collegati: ${referredUsersCount.toInt()}",
                          style: AppTextStyles.body,
                        ),
                        Text(
                          "Operazioni confermate invitati: ${referredOps.toInt()}",
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReferredUsersPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.group),
                      label: const Text("I tuoi suggeriti"),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Text(
            "Ultime richieste",
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _purchasesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text(
                  "Caricamento...",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                );
              }
              final items = snapshot.data ?? <Map<String, dynamic>>[];
              if (items.isEmpty) {
                return const Text(
                  "Nessuna richiesta trovata.",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                );
              }

              final byMonth = <String, List<Map<String, dynamic>>>{};
              for (final it in items) {
                final dt = _parseCreatedAt(it) ?? DateTime.now();
                final key = _monthKey(dt);
                byMonth.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(it);
              }
              final monthKeys = byMonth.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return Column(
                children: monthKeys.map((monthKey) {
                  final monthItems = byMonth[monthKey]!..sort((a, b) {
                    final ad = _parseCreatedAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bd = _parseCreatedAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bd.compareTo(ad);
                  });

                  final isExpanded = _expandedMonths.contains(monthKey);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedMonths.remove(monthKey);
                              } else {
                                _expandedMonths.add(monthKey);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "${_monthLabelFromKey(monthKey)} (${monthItems.length})",
                                    style: AppTextStyles.pageMessage,
                                  ),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              children: monthItems.map((it) {
                  final totalCents = (it["totalCents"] ?? 0) as num;
                  final status = (it["status"] ?? "").toString();
                  final rejectionCode = (it["rejectionCode"] ?? "").toString();
                  final userCashbackCents =
                      (it["userCashbackCents"] ?? 0) as num;
                  final activityName =
                      (it["activityName"] ??
                              it["insegna"] ??
                              it["activityTitle"] ??
                              it["businessName"] ??
                              "")
                          .toString()
                          .trim();
                  final country =
                      (it["country"] ??
                              it["paese"] ??
                              it["activityCountry"] ??
                              it["activityPaese"] ??
                              "")
                          .toString()
                          .trim();
                  final activityType =
                      (it["activityType"] ??
                              it["tipo_attivita"] ??
                              it["tipoAttivita"] ??
                              it["typeLabel"] ??
                              "")
                          .toString()
                          .trim();
                  final whereLabel = activityName.isNotEmpty
                      ? activityName
                      : "N/D";
                  final countryLabel = country.isNotEmpty ? country : "N/D";
                  final typeLabel =
                      activityType.isNotEmpty ? activityType : "N/D";

                  String subtitle = "";
                  if (status == "pending_merchant") {
                    subtitle = "In attesa di conferma (max 24 ore)";
                  } else if (status == "confirmed") {
                    subtitle =
                        "Confermata. Cashback: € ${_fmtEuroFromCents(userCashbackCents)}";
                  } else if (status == "rejected") {
                    subtitle = rejectionCode.isEmpty
                        ? "Rifiutata"
                        : "Rifiutata: $rejectionCode";
                  } else {
                    subtitle = status;
                  }

                                return Container(
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
                                      Text(
                                        "Spesa: € ${_fmtEuroFromCents(totalCents)}",
                                        style: AppTextStyles.pageMessage,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Attività: $whereLabel",
                                        style: AppTextStyles.body,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Paese: $countryLabel",
                                        style: AppTextStyles.body,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Tipo attività: $typeLabel",
                                        style: AppTextStyles.body,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(subtitle, style: AppTextStyles.body),
                                      if (status == "confirmed") ...[
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () async {
                                              final purchaseId =
                                                  (it["purchaseId"] ?? "")
                                                      .toString()
                                                      .trim();
                                              final activityRequestId =
                                                  (it["activityRequestId"] ?? "")
                                                      .toString()
                                                      .trim();

                                              if (purchaseId.isEmpty ||
                                                  activityRequestId.isEmpty) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      "Recensione non disponibile per questa operazione.",
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              final changed = await Navigator.of(
                                                this.context,
                                              ).push<bool>(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PurchaseReviewPage(
                                                        purchaseId: purchaseId,
                                                        activityRequestId:
                                                            activityRequestId,
                                                        activityName: whereLabel,
                                                        activityType: typeLabel,
                                                      ),
                                                ),
                                              );

                                              if (changed == true && mounted) {
                                                ScaffoldMessenger.of(this.context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      "Recensione aggiornata.",
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.reviews_outlined,
                                            ),
                                            label: const Text("Recensisci"),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
