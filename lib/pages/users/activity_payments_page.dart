import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/logiche/requests/purchase_service.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/theme/app_colors.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/utils/date_format_it.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tipicooo/utils/csv_downloader.dart';

class ActivityPaymentsPage extends StatefulWidget {
  const ActivityPaymentsPage({super.key, this.activityRequestId});

  // Optional: open directly on a specific activity (from a notification).
  final String? activityRequestId;

  @override
  State<ActivityPaymentsPage> createState() => _ActivityPaymentsPageState();
}

class _PendingRow {
  _PendingRow({
    required this.activityRequestId,
    required this.activityName,
    required this.activityType,
    required this.purchaseId,
    required this.totalCents,
    required this.createdAt,
    required this.expiresAt,
    required this.requesterEmail,
  });

  final String activityRequestId;
  final String activityName;
  final String activityType;
  final String purchaseId;
  final int totalCents;
  final String createdAt;
  final String expiresAt;
  final String requesterEmail;
}

class _OpRow {
  _OpRow({
    required this.activityRequestId,
    required this.activityName,
    required this.activityType,
    required this.purchaseId,
    required this.status,
    required this.totalCents,
    required this.createdAt,
    required this.handledAt,
    required this.requesterEmail,
    required this.handledByName,
    required this.handledByEmail,
    required this.cashbackTotalCents,
    required this.platformCashbackCents,
    required this.userCashbackCents,
    required this.referrerCashbackCents,
    required this.rejectionCode,
  });

  final String activityRequestId;
  final String activityName;
  final String activityType;
  final String purchaseId;
  final String status;
  final int totalCents;
  final String createdAt;
  final String handledAt;
  final String requesterEmail;
  final String handledByName;
  final String handledByEmail;
  final int cashbackTotalCents;
  final int platformCashbackCents;
  final int userCashbackCents;
  final int referrerCashbackCents;
  final String rejectionCode;
}

class _ActivityPaymentsPageState extends State<ActivityPaymentsPage> {
  bool _loading = true;
  String? _error;
  List<_PendingRow> _pending = [];
  List<_OpRow> _ops = [];
  int _tabIndex = 0; // 0=pending, 1=ops
  late String _monthKey;
  String? _activityFilterRequestId; // null => tutte
  List<Map<String, dynamic>> _approvedActivities = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthKey =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";

    // Se la pagina e' stata aperta da notifica (su una specifica attivita'),
    // blocchiamo il filtro su quella attivita'.
    if (widget.activityRequestId != null &&
        widget.activityRequestId!.trim().isNotEmpty) {
      _activityFilterRequestId = widget.activityRequestId!.trim();
    }
    _refresh();
  }

  String _fmtEuroFromCents(int cents) {
    final sign = cents < 0 ? "-" : "";
    final abs = cents.abs();
    final euro = abs ~/ 100;
    final cent = abs % 100;
    return "$sign$euro,${cent.toString().padLeft(2, '0')}";
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final activities = await ActivityRequestService.fetchActivitiesForMe();
      final approved = activities.where((it) {
        final status = (it["status"] ?? "").toString();
        if (status != "approved") return false;
        final requestId = (it["requestId"] ?? "").toString().trim();
        if (requestId.isEmpty) return false;
        if (widget.activityRequestId == null) return true;
        return widget.activityRequestId == requestId;
      }).toList();

      _approvedActivities = approved;

      final String? filterId =
          (_activityFilterRequestId == null ||
              _activityFilterRequestId!.trim().isEmpty ||
              widget.activityRequestId != null)
          ? _activityFilterRequestId
          : _activityFilterRequestId;

      final filteredApproved = (filterId == null || filterId.trim().isEmpty)
          ? approved
          : approved
                .where(
                  (a) => (a["requestId"] ?? "").toString().trim() == filterId,
                )
                .toList();

      if (_tabIndex == 0) {
        final rows = <_PendingRow>[];
        for (final a in filteredApproved) {
          final requestId = (a["requestId"] ?? "").toString().trim();
          final insegna = (a["insegna"] ?? "Attività").toString().trim();
          final activityType =
              (a["tipo_attivita"] ?? a["categoria"] ?? a["activity_type"] ?? "")
                  .toString()
                  .trim();
          if (requestId.isEmpty) continue;

          final pending = await PurchaseService.fetchPendingForActivity(
            activityRequestId: requestId,
            limit: 100,
          );

          for (final p in pending) {
            final purchaseId = (p["purchaseId"] ?? "").toString().trim();
            if (purchaseId.isEmpty) continue;
            final requesterEmail = (p["requesterEmail"] ?? "")
                .toString()
                .trim();
            rows.add(
              _PendingRow(
                activityRequestId: requestId,
                activityName: insegna.isEmpty ? "Attività" : insegna,
                activityType: activityType,
                purchaseId: purchaseId,
                totalCents: (p["totalCents"] is num)
                    ? (p["totalCents"] as num).toInt()
                    : 0,
                createdAt: (p["createdAt"] ?? "").toString(),
                expiresAt: (p["expiresAt"] ?? "").toString(),
                requesterEmail: requesterEmail,
              ),
            );
          }
        }

        rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        setState(() {
          _pending = rows;
          _loading = false;
        });
      } else {
        final rows = <_OpRow>[];
        for (final a in filteredApproved) {
          final requestId = (a["requestId"] ?? "").toString().trim();
          final insegna = (a["insegna"] ?? "Attività").toString().trim();
          final activityType =
              (a["tipo_attivita"] ?? a["categoria"] ?? a["activity_type"] ?? "")
                  .toString()
                  .trim();
          if (requestId.isEmpty) continue;

          final ops = await PurchaseService.fetchMonthOperationsForActivity(
            activityRequestId: requestId,
            monthKey: _monthKey,
            limit: 500,
          );

          for (final p in ops) {
            final purchaseId = (p["purchaseId"] ?? "").toString().trim();
            if (purchaseId.isEmpty) continue;
            rows.add(
              _OpRow(
                activityRequestId: requestId,
                activityName: insegna.isEmpty ? "Attività" : insegna,
                activityType: activityType,
                purchaseId: purchaseId,
                status: (p["status"] ?? "").toString(),
                totalCents: (p["totalCents"] is num)
                    ? (p["totalCents"] as num).toInt()
                    : 0,
                createdAt: (p["createdAt"] ?? "").toString(),
                handledAt:
                    (p["handledAt"] ??
                            p["confirmedAt"] ??
                            p["rejectedAt"] ??
                            "")
                        .toString(),
                requesterEmail: (p["requesterEmail"] ?? "").toString().trim(),
                handledByName: (p["handledByName"] ?? "").toString().trim(),
                handledByEmail: (p["handledByEmail"] ?? "").toString().trim(),
                cashbackTotalCents: (p["cashbackTotalCents"] is num)
                    ? (p["cashbackTotalCents"] as num).toInt()
                    : 0,
                platformCashbackCents: (p["platformCashbackCents"] is num)
                    ? (p["platformCashbackCents"] as num).toInt()
                    : 0,
                userCashbackCents: (p["userCashbackCents"] is num)
                    ? (p["userCashbackCents"] as num).toInt()
                    : 0,
                referrerCashbackCents: (p["referrerCashbackCents"] is num)
                    ? (p["referrerCashbackCents"] as num).toInt()
                    : 0,
                rejectionCode: (p["rejectionCode"] ?? "").toString().trim(),
              ),
            );
          }
        }

        String sortKey(_OpRow it) {
          final k = it.handledAt.trim().isEmpty ? it.createdAt : it.handledAt;
          return k;
        }

        rows.sort((a, b) => sortKey(b).compareTo(sortKey(a)));

        setState(() {
          _ops = rows;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<DropdownMenuItem<String?>> _activityFilterItems() {
    // "Tutte" + elenco approvate (insegna come label).
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text("Tutte le attività"),
      ),
    ];

    for (final a in _approvedActivities) {
      final id = (a["requestId"] ?? "").toString().trim();
      if (id.isEmpty) continue;
      final insegna = (a["insegna"] ?? "").toString().trim();
      final ragione = (a["ragione_sociale"] ?? "").toString().trim();
      final label = insegna.isNotEmpty
          ? insegna
          : (ragione.isNotEmpty ? ragione : id);
      items.add(DropdownMenuItem<String?>(value: id, child: Text(label)));
    }

    return items;
  }

  List<String> _monthOptions({int monthsBack = 12}) {
    final now = DateTime.now();
    final out = <String>[];
    for (int i = 0; i <= monthsBack; i++) {
      final dt = DateTime(now.year, now.month - i, 1);
      out.add(
        "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}",
      );
    }
    return out;
  }

  Future<void> _downloadCsv() async {
    final rows = _ops;
    if (rows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nessuna operazione da scaricare.")),
      );
      return;
    }

    String esc(String v) {
      final s = v.replaceAll('"', '""');
      if (s.contains(",") ||
          s.contains("\n") ||
          s.contains("\r") ||
          s.contains('"')) {
        return '"$s"';
      }
      return s;
    }

    final lines = <String>[];
    lines.add(
      [
        "mese",
        "attivita",
        "tipo_attivita",
        "stato",
        "importo_eur",
        "cashback_10_eur",
        "quota_tipicooo_eur",
        "quota_cliente_eur",
        "quota_suggeritore_eur",
        "email_cliente",
        "gestito_da_nome",
        "gestito_da_email",
        "gestito_il",
        "richiesto_il",
        "motivo_rifiuto",
      ].join(","),
    );

    for (final r in rows) {
      lines.add(
        [
          esc(_monthKey),
          esc(r.activityName),
          esc(r.activityType),
          esc(r.status),
          esc(_fmtEuroFromCents(r.totalCents)),
          esc(_fmtEuroFromCents(r.cashbackTotalCents)),
          esc(_fmtEuroFromCents(r.platformCashbackCents)),
          esc(_fmtEuroFromCents(r.userCashbackCents)),
          esc(_fmtEuroFromCents(r.referrerCashbackCents)),
          esc(r.requesterEmail),
          esc(r.handledByName),
          esc(r.handledByEmail),
          esc(r.handledAt),
          esc(r.createdAt),
          esc(r.rejectionCode),
        ].join(","),
      );
    }

    final csv = lines.join("\n");
    final filename =
        "tipicooo_operazioni_${_monthKey.replaceAll('-', '_')}.csv";
    await downloadCsv(filename: filename, csvContent: csv);
  }

  Future<void> _confirm(_PendingRow row) async {
    final ok = await PurchaseService.confirmPurchase(purchaseId: row.purchaseId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore conferma pagamento.")),
      );
      return;
    }

    final when = DateFormatIt.dateTimeFromIso(row.createdAt);
    NotificationController.instance.addNotification(
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: "Pagamento confermato",
        message:
            "${row.activityName}: pagamento di € ${_fmtEuroFromCents(row.totalCents)} (richiesto il $when).",
        timestamp: DateTime.now(),
        action: "open_activity_payments|${row.activityRequestId}",
      ),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Pagamento confermato.")));
    await _refresh();
  }

  Future<void> _reject(_PendingRow row) async {
    const codes = <String>[
      "PAYMENT_NOT_COMPLETED",
      "AMOUNT_INCORRECT",
      "NOT_RECOGNIZED",
      "EXPIRED_NO_RESPONSE",
      "OTHER",
    ];
    String selected = codes.first;
    final noteController = TextEditingController();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Rifiuta pagamento", style: AppTextStyles.body),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Seleziona il motivo:", style: AppTextStyles.body),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    value: selected,
                    isExpanded: true,
                    items: codes
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => selected = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: "Nota (facoltativa)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Annulla", style: AppTextStyles.body),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    "Rifiuta",
                    style: AppTextStyles.body.copyWith(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) return;

    final ok = await PurchaseService.rejectPurchase(
      purchaseId: row.purchaseId,
      rejectionCode: selected,
      rejectionNote: noteController.text.trim(),
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore rifiuto pagamento.")),
      );
      return;
    }

    final when = DateFormatIt.dateTimeFromIso(row.createdAt);
    NotificationController.instance.addNotification(
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: "Pagamento rifiutato",
        message:
            "${row.activityName}: pagamento di € ${_fmtEuroFromCents(row.totalCents)} rifiutato (richiesto il $when).",
        timestamp: DateTime.now(),
        action: "open_activity_payments|${row.activityRequestId}",
      ),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Pagamento rifiutato.")));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: false,
      headerTitle: "Accetta pagamenti",
      onRefresh: _refresh,
      showBack: true,
      showHome: true,
      showProfile: true,
      showBell: true,
      showLogout: false,
      body: AppBodyLayout(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ToggleButtons(
                isSelected: [_tabIndex == 0, _tabIndex == 1],
                onPressed: (idx) async {
                  if (_tabIndex == idx) return;
                  setState(() {
                    _tabIndex = idx;
                  });
                  await _refresh();
                },
                borderRadius: BorderRadius.circular(10),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text("In attesa"),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text("Movimenti"),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_tabIndex == 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.activityRequestId == null) ...[
                  DropdownButton<String?>(
                    value: _activityFilterRequestId,
                    items: _activityFilterItems(),
                    onChanged: (v) async {
                      setState(() {
                        _activityFilterRequestId = v;
                      });
                      await _refresh();
                    },
                  ),
                  const SizedBox(width: 10),
                ],
                DropdownButton<String>(
                  value: _monthKey,
                  items: _monthOptions()
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null || v == _monthKey) return;
                    setState(() {
                      _monthKey = v;
                    });
                    await _refresh();
                  },
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _downloadCsv,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text("Scarica"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_loading && _ops.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final confirmed = _ops
                      .where((o) => o.status == "confirmed")
                      .toList();
                  int sum(List<int> xs) => xs.fold(0, (a, b) => a + b);
                  final totalSpent = sum(
                    confirmed.map((o) => o.totalCents).toList(),
                  );
                  final totalCommission = sum(
                    confirmed.map((o) => o.cashbackTotalCents).toList(),
                  );

                  return Container(
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
                          "Riepilogo $_monthKey",
                          style: AppTextStyles.pageMessage,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Totale scontrini (confermati): € ${_fmtEuroFromCents(totalSpent)}",
                          style: AppTextStyles.body,
                        ),
                        Text(
                          "Commissioni (10%): € ${_fmtEuroFromCents(totalCommission)}",
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
          if (_tabIndex == 0 && widget.activityRequestId == null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<String?>(
                  value: _activityFilterRequestId,
                  items: _activityFilterItems(),
                  onChanged: (v) async {
                    setState(() {
                      _activityFilterRequestId = v;
                    });
                    await _refresh();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _tabIndex == 0 ? "Pagamenti in attesa" : "Movimenti del mese",
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          else if (_error != null)
            Text(
              "Errore: $_error",
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            )
          else if (_tabIndex == 0 && _pending.isEmpty)
            const Text(
              "Nessuna richiesta in attesa.",
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            )
          else if (_tabIndex == 1 && _ops.isEmpty)
            const Text(
              "Nessuna operazione in questo mese.",
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            )
          else if (_tabIndex == 0)
            Column(
              children: _pending.map((r) {
                return Container(
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
                      if (r.activityType.trim().isNotEmpty) ...[
                        Text(
                          r.activityType.trim(),
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(r.activityName, style: AppTextStyles.pageMessage),
                      const SizedBox(height: 6),
                      if (r.requesterEmail.trim().isNotEmpty) ...[
                        InkWell(
                          onTap: () async {
                            final email = r.requesterEmail.trim();
                            final uri = Uri(scheme: 'mailto', path: email);
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          child: Text(
                            "Email: ${r.requesterEmail.trim()}",
                            style: AppTextStyles.body.copyWith(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        "Importo: € ${_fmtEuroFromCents(r.totalCents)}",
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Richiesta: ${DateFormatIt.dateTimeFromIso(r.createdAt)}",
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _reject(r),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text("Rifiuta"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _confirm(r),
                              child: const Text("Conferma"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            Column(
              children: _ops.map((r) {
                final isConfirmed = r.status == "confirmed";
                final isRejected = r.status == "rejected";
                final statusLabel = isConfirmed
                    ? "Confermata"
                    : isRejected
                    ? (r.rejectionCode.isEmpty
                          ? "Rifiutata"
                          : "Rifiutata: ${r.rejectionCode}")
                    : r.status;
                final handler = r.handledByName.isNotEmpty
                    ? r.handledByName
                    : (r.handledByEmail.isNotEmpty ? r.handledByEmail : "-");

                return Container(
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
                      if (r.activityType.trim().isNotEmpty) ...[
                        Text(
                          r.activityType.trim(),
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(r.activityName, style: AppTextStyles.pageMessage),
                      const SizedBox(height: 6),
                      Text(statusLabel, style: AppTextStyles.body),
                      const SizedBox(height: 6),
                      if (r.requesterEmail.trim().isNotEmpty) ...[
                        InkWell(
                          onTap: () async {
                            final email = r.requesterEmail.trim();
                            final uri = Uri(scheme: 'mailto', path: email);
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          child: Text(
                            "Cliente: ${r.requesterEmail.trim()}",
                            style: AppTextStyles.body.copyWith(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        "Importo: € ${_fmtEuroFromCents(r.totalCents)}",
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 4),
                      Text("Gestito da: $handler", style: AppTextStyles.body),
                      const SizedBox(height: 4),
                      Text(
                        "Gestito: ${DateFormatIt.dateTimeFromIso(r.handledAt)}",
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Richiesta: ${DateFormatIt.dateTimeFromIso(r.createdAt)}",
                        style: AppTextStyles.body,
                      ),
                      if (isConfirmed && r.cashbackTotalCents > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Commissioni (10%): € ${_fmtEuroFromCents(r.cashbackTotalCents)}",
                          style: AppTextStyles.body,
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text("Aggiorna"),
          ),
        ],
      ),
    );
  }
}
