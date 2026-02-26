import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/requests/review_service.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

class PurchaseReviewPage extends StatefulWidget {
  const PurchaseReviewPage({
    super.key,
    required this.purchaseId,
    required this.activityRequestId,
    required this.activityName,
    required this.activityType,
  });

  final String purchaseId;
  final String activityRequestId;
  final String activityName;
  final String activityType;

  @override
  State<PurchaseReviewPage> createState() => _PurchaseReviewPageState();
}

class _PurchaseReviewPageState extends State<PurchaseReviewPage> {
  final TextEditingController _reasonController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  int _serviceScore = 8;
  int _cleanlinessScore = 8;
  int _courtesyScore = 8;
  bool? _wouldRecommend;

  bool get _isProfessionalType {
    final t = widget.activityType.trim().toLowerCase();
    if (t.isEmpty) return false;
    return t.contains("libero professionista") ||
        t.contains("professionista") ||
        t.contains("consulente") ||
        t.contains("avvocato") ||
        t.contains("commercialista") ||
        t.contains("tecnico");
  }

  String get _label1 => _isProfessionalType ? "Competenza" : "Servizio";
  String get _label2 => _isProfessionalType ? "Puntualità" : "Pulizia";
  String get _label3 =>
      _isProfessionalType ? "Chiarezza / Comunicazione" : "Cortesia";

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingReview() async {
    final review = await ReviewService.fetchMyReview(
      purchaseId: widget.purchaseId,
    );
    if (!mounted) return;

    if (review != null && review.isNotEmpty) {
      int readScore(List<String> keys, int fallback) {
        dynamic v;
        for (final k in keys) {
          v = review[k];
          if (v != null) break;
        }
        if (v is num) return v.toInt().clamp(1, 10);
        if (v is String) {
          final n = int.tryParse(v.trim());
          if (n != null) return n.clamp(1, 10);
        }
        return fallback;
      }

      bool? readBool(String key) {
        final v = review[key];
        if (v is bool) return v;
        if (v is String) {
          final s = v.trim().toLowerCase();
          if (s == "true" || s == "si" || s == "sì") return true;
          if (s == "false" || s == "no") return false;
        }
        return null;
      }

      setState(() {
        _serviceScore = readScore(
          const ["score1", "serviceScore"],
          _serviceScore,
        );
        _cleanlinessScore = readScore(
          const ["score2", "cleanlinessScore"],
          _cleanlinessScore,
        );
        _courtesyScore = readScore(
          const ["score3", "courtesyScore"],
          _courtesyScore,
        );
        _wouldRecommend = readBool("wouldRecommend");
        _reasonController.text =
            (review["notRecommendReason"] ?? "").toString().trim();
      });
    }

    setState(() => _loading = false);
  }

  List<DropdownMenuItem<int>> _scoreItems() {
    return List<DropdownMenuItem<int>>.generate(
      10,
      (i) => DropdownMenuItem<int>(
        value: i + 1,
        child: Text("${i + 1}"),
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_wouldRecommend == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Seleziona se consiglieresti l'attività."),
        ),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    if (_wouldRecommend == false && reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Se non consigli l'attività, inserisci un motivo (almeno 10 caratteri).",
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final ok = await ReviewService.upsertReview(
      purchaseId: widget.purchaseId,
      activityRequestId: widget.activityRequestId,
      score1: _serviceScore,
      score2: _cleanlinessScore,
      score3: _courtesyScore,
      score1Label: _label1,
      score2Label: _label2,
      score3Label: _label3,
      wouldRecommend: _wouldRecommend == true,
      notRecommendReason: _wouldRecommend == true ? "" : reason,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore nel salvataggio della recensione.")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Recensione salvata.")),
    );
    Navigator.of(context).pop(true);
  }

  Widget _scoreField({
    required String label,
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: value,
          items: _scoreItems(),
          onChanged: onChanged,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Da 1 a 10",
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: false,
      headerTitle: "Recensione",
      showBack: true,
      showHome: true,
      showProfile: true,
      showBell: false,
      showLogout: false,
      body: AppBodyLayout(
        children: [
          Text(
            widget.activityName.trim().isEmpty ? "Attività" : widget.activityName.trim(),
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          const Text(
            "Valuta la tua esperienza (punteggio da 1 a 10).",
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _scoreField(
              label: _label1,
              value: _serviceScore,
              onChanged: (v) => setState(() => _serviceScore = (v ?? 8)),
            ),
            const SizedBox(height: 12),
            _scoreField(
              label: _label2,
              value: _cleanlinessScore,
              onChanged: (v) => setState(() => _cleanlinessScore = (v ?? 8)),
            ),
            const SizedBox(height: 12),
            _scoreField(
              label: _label3,
              value: _courtesyScore,
              onChanged: (v) => setState(() => _courtesyScore = (v ?? 8)),
            ),
            const SizedBox(height: 14),
            const Text("Lo consiglieresti?", style: AppTextStyles.body),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(value: true, label: Text("Sì")),
                  ButtonSegment<bool>(value: false, label: Text("No")),
                ],
                selected: _wouldRecommend == null
                    ? const <bool>{}
                    : <bool>{_wouldRecommend!},
                onSelectionChanged: (selection) {
                  setState(() {
                    _wouldRecommend =
                        selection.isEmpty ? null : selection.first;
                  });
                },
                showSelectedIcon: false,
              ),
            ),
            if (_wouldRecommend == false) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: "Perché non lo consiglieresti?",
                  hintText: "Scrivi il motivo",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            BlueNarrowButton(
              label: _saving ? "Salvataggio..." : "Salva recensione",
              icon: Icons.check_circle_outline,
              onPressed: _saving ? () {} : _submit,
            ),
          ],
        ],
      ),
    );
  }
}
