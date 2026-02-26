import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/affiliate/affiliate_activity_service.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

class AffiliateActivityStatusPage extends StatefulWidget {
  const AffiliateActivityStatusPage({super.key});

  @override
  State<AffiliateActivityStatusPage> createState() =>
      _AffiliateActivityStatusPageState();
}

class _AffiliateActivityStatusPageState extends State<AffiliateActivityStatusPage> {
  late Future<List<AffiliateLeadStatus>> _future;

  @override
  void initState() {
    super.initState();
    _future = AffiliateActivityService.getMyLeadStatuses();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = AffiliateActivityService.getMyLeadStatuses();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: true,
      headerTitle: "Stato attività affiliate",
      showBack: true,
      showHome: true,
      showProfile: true,
      showBell: true,
      showLogout: false,
      onRefresh: _refresh,
      body: AppBodyLayout(
        children: [
          const SizedBox(height: 10),
          const Text(
            "Monitoraggio affiliazioni",
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const Text(
            "Vedi se l’attività si è affiliata e se sta generando incassi. Gli importi non vengono mostrati.",
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          FutureBuilder<List<AffiliateLeadStatus>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? <AffiliateLeadStatus>[];
              if (items.isEmpty) {
                return const Text(
                  "Non hai ancora attività suggerite.",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                );
              }

              final affiliatedCount = items.where((e) => e.isAffiliated).length;
              final generatingCount = items.where((e) => e.isGenerating).length;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: "Affiliate",
                          value: "$affiliatedCount/${items.length}",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          label: "Generano incassi",
                          value: "$generatingCount/${items.length}",
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Elenco attività suggerite",
                          style: AppTextStyles.pageMessage,
                        ),
                        const SizedBox(height: 10),
                        for (final it in items)
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
                                Text(
                                  it.lead.activityName,
                                  style: AppTextStyles.pageMessage.copyWith(
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Referente: ${it.lead.referente}",
                                  style: AppTextStyles.body,
                                ),
                                Text(
                                  "Email: ${it.lead.activityEmail}",
                                  style: AppTextStyles.body,
                                ),
                                if (it.city.trim().isNotEmpty)
                                  Text(
                                    "Città: ${it.city}",
                                    style: AppTextStyles.body,
                                  ),
                                if (it.activityType.trim().isNotEmpty)
                                  Text(
                                    "Tipo attività: ${it.activityType}",
                                    style: AppTextStyles.body,
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _StatusChip(
                                      label: it.isAffiliated
                                          ? "Affiliata"
                                          : "Non affiliata",
                                      color: it.isAffiliated
                                          ? const Color(0xFF0B5ED7)
                                          : const Color(0xFF7A7A7A),
                                    ),
                                    _StatusChip(
                                      label: it.isGenerating
                                          ? "Sta generando incassi"
                                          : "Non genera ancora incassi",
                                      color: it.isGenerating
                                          ? const Color(0xFF1D9B4E)
                                          : const Color(0xFFF08C00),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
