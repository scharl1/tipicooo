import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/logiche/requests/staff_join_service.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/theme/app_colors.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/utils/date_format_it.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';
import 'package:url_launcher/url_launcher.dart';

class ManageStaffPage extends StatefulWidget {
  const ManageStaffPage({super.key});

  @override
  State<ManageStaffPage> createState() => _ManageStaffPageState();
}

class _ManageStaffPageState extends State<ManageStaffPage> {
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  List<Map<String, dynamic>> _ownedActivities = [];
  String? _selectedActivityId;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invites = [];
  final TextEditingController _inviteEmailController = TextEditingController();
  String? _inviteStatusMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _activityLabel(Map<String, dynamic> a) {
    final insegna = (a["insegna"] ?? "").toString().trim();
    final ragione = (a["ragione_sociale"] ?? "").toString().trim();
    if (insegna.isNotEmpty) return insegna;
    if (ragione.isNotEmpty) return ragione;
    return (a["requestId"] ?? "Attività").toString();
  }

  String _inviteMessage() {
    final id = (_selectedActivityId ?? "").trim();
    final activity = _ownedActivities.firstWhere(
      (a) => (a["requestId"] ?? "").toString() == id,
      orElse: () => <String, dynamic>{},
    );
    final name = _activityLabel(activity).trim();
    return "Ciao, ti invito come dipendente per i pagamenti su Tipic.ooo.\n"
        "Attività: $name\n"
        "Codice attività: $id\n\n"
        "Apri Tipic.ooo, vai in Dipendenti e inserisci questo codice per inviare la richiesta.";
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    super.dispose();
  }

  void _notifyInviteSent(String channel) {
    NotificationController.instance.addNotification(
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: "Richiesta dipendente inviata",
        message: "Richiesta al dipendente inviata in attesa di conferma.",
        timestamp: DateTime.now(),
        action: "open_staff_manage",
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Invito inviato via $channel.")),
    );
  }

  Future<void> _sendInviteWhatsApp() async {
    final id = (_selectedActivityId ?? "").trim();
    if (id.isEmpty) return;
    final text = Uri.encodeComponent(_inviteMessage());
    final whatsappUri = Uri.parse("whatsapp://send?text=$text");
    final waMeUri = Uri.parse("https://wa.me/?text=$text");

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      _notifyInviteSent("WhatsApp");
      return;
    }
    if (await canLaunchUrl(waMeUri)) {
      await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      _notifyInviteSent("WhatsApp");
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("WhatsApp non disponibile su questo dispositivo."),
      ),
    );
  }

  Future<void> _sendInviteEmail() async {
    final id = (_selectedActivityId ?? "").trim();
    if (id.isEmpty) return;
    final uri = Uri(
      scheme: "mailto",
      queryParameters: {
        "subject": "Invito dipendente pagamenti Tipic.ooo",
        "body": _inviteMessage(),
      },
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) {
      _notifyInviteSent("Email");
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Nessuna app email disponibile.")),
    );
  }

  Future<void> _sendInviteInApp() async {
    final activityId = (_selectedActivityId ?? "").trim();
    final inviteeEmail = _inviteEmailController.text.trim().toLowerCase();
    if (activityId.isEmpty || inviteeEmail.isEmpty) return;
    setState(() => _actionLoading = true);
    final ok = await StaffJoinService.sendInviteToEmail(
      activityRequestId: activityId,
      inviteeEmail: inviteeEmail,
    );
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (ok) {
      setState(() {
        _inviteEmailController.clear();
        _inviteStatusMessage =
            "Invito in app inviato. In attesa che il dipendente confermi con il codice attività.";
      });
      _notifyInviteSent("Tipic.ooo");
      return;
    }
    setState(() {
      _inviteStatusMessage = "Invio non riuscito. Riprova.";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Errore invio invito in app.")),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final activities = await ActivityRequestService.fetchActivitiesForMe();
      final owned = activities.where((a) {
        final status = (a["status"] ?? "").toString();
        if (status != "approved") return false;
        final roleType = (a["roleType"] ?? "").toString().toLowerCase().trim();
        return roleType == "owner";
      }).toList();

      String? selected = _selectedActivityId;
      if (selected == null ||
          owned.every((a) => (a["requestId"] ?? "").toString() != selected)) {
        selected = owned.isNotEmpty
            ? (owned.first["requestId"] ?? "").toString()
            : null;
      }

      _ownedActivities = owned;
      _selectedActivityId = selected;

      if (selected != null && selected.isNotEmpty) {
        _pending = await StaffJoinService.listPending(
          activityRequestId: selected,
        );
        _members = await StaffJoinService.listMembers(
          activityRequestId: selected,
        );
        _invites = await StaffJoinService.listOwnerInvites(
          activityRequestId: selected,
        );
      } else {
        _pending = [];
        _members = [];
        _invites = [];
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _reloadAll() async {
    final id = _selectedActivityId;
    if (id == null || id.isEmpty) return;
    setState(() => _actionLoading = true);
    final pending = await StaffJoinService.listPending(activityRequestId: id);
    final members = await StaffJoinService.listMembers(activityRequestId: id);
    final invites = await StaffJoinService.listOwnerInvites(activityRequestId: id);
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _members = members;
      _invites = invites;
      _actionLoading = false;
    });
  }

  Future<void> _approve(String staffUserId) async {
    final id = _selectedActivityId;
    if (id == null || id.isEmpty) return;
    setState(() => _actionLoading = true);
    final ok = await StaffJoinService.approve(
      activityRequestId: id,
      staffUserId: staffUserId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? "Dipendente approvato." : "Errore approvazione."),
      ),
    );
    if (ok) {
      await _reloadAll();
    } else {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _reject(String staffUserId) async {
    final id = _selectedActivityId;
    if (id == null || id.isEmpty) return;
    setState(() => _actionLoading = true);
    final ok = await StaffJoinService.reject(
      activityRequestId: id,
      staffUserId: staffUserId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "Richiesta rifiutata." : "Errore rifiuto.")),
    );
    if (ok) {
      await _reloadAll();
    } else {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _removeMember(String staffUserId) async {
    final id = _selectedActivityId;
    if (id == null || id.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rimuovi dipendente"),
        content: const Text("Confermi la rimozione dai pagamenti?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annulla"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Rimuovi"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading = true);
    final ok = await StaffJoinService.removeMember(
      activityRequestId: id,
      staffUserId: staffUserId,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "Dipendente rimosso." : "Errore rimozione.")),
    );

    if (ok) {
      await _reloadAll();
    } else {
      setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: false,
      headerTitle: "Dipendenti",
      showBack: true,
      showHome: true,
      showProfile: true,
      showBell: true,
      showLogout: false,
      body: Stack(
        children: [
          AppBodyLayout(
            children: [
              const Text(
                "Gestisci richieste staff e dipendenti attivi",
                style: AppTextStyles.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryBlue,
                  ),
                )
              else if (_error != null)
                Text(
                  "Errore: $_error",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                )
              else if (_ownedActivities.isEmpty)
                const Text(
                  "Nessuna attività owner approvata.",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                )
              else ...[
                DropdownButton<String>(
                  value: _selectedActivityId,
                  isExpanded: true,
                  items: _ownedActivities.map((a) {
                    final id = (a["requestId"] ?? "").toString();
                    return DropdownMenuItem(
                      value: id,
                      child: Text(_activityLabel(a)),
                    );
                  }).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() {
                      _selectedActivityId = v;
                    });
                    await _reloadAll();
                  },
                ),
                const SizedBox(height: 12),
                Container(
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
                        "Codice attività: ${_selectedActivityId ?? '-'}",
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Condividi questo codice con i dipendenti per fargli inviare la richiesta.",
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _inviteEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email dipendente",
                    hintText: "nome@email.it",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _actionLoading ? null : _sendInviteInApp,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text("Invia invito in app"),
                  ),
                ),
                if ((_inviteStatusMessage ?? "").trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _inviteStatusMessage!,
                    style: AppTextStyles.body,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _actionLoading ? null : _sendInviteWhatsApp,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text("Invia via WhatsApp"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _actionLoading ? null : _sendInviteEmail,
                        icon: const Icon(Icons.mail_outline),
                        label: const Text("Invia via Email"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Inviti in attesa conferma: ${_invites.length}",
                  style: AppTextStyles.pageMessage,
                ),
                const SizedBox(height: 8),
                if (_invites.isEmpty)
                  const Text(
                    "Nessun invito inviato in attesa.",
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  )
                else
                  Column(
                    children: _invites.map((it) {
                      final email = (it["inviteeEmail"] ?? "").toString().trim();
                      final createdAt = (it["createdAt"] ?? "").toString().trim();
                      final createdAtLabel = DateFormatIt.dateTimeFromIso(createdAt);
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
                            Text(
                              email.isNotEmpty ? email : "Email non disponibile",
                              style: AppTextStyles.pageMessage,
                            ),
                            if (createdAtLabel.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Inviato: $createdAtLabel",
                                style: AppTextStyles.body,
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _actionLoading ? null : _reloadAll,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Aggiorna"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_pending.isNotEmpty)
                  Column(
                    children: _pending.map((r) {
                      final staffUserId = (r["requesterUserId"] ?? "")
                          .toString();
                      final email = (r["requesterEmail"] ?? "").toString();
                      final name = (r["requesterName"] ?? "").toString();
                      final createdAt = (r["createdAt"] ?? "").toString();
                      final createdAtLabel = DateFormatIt.dateTimeFromIso(
                        createdAt,
                      );
                      final title = name.trim().isNotEmpty
                          ? name
                          : (email.isNotEmpty ? email : staffUserId);

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
                            Text(title, style: AppTextStyles.pageMessage),
                            const SizedBox(height: 4),
                            if (email.trim().isNotEmpty)
                              Text("Email: $email", style: AppTextStyles.body),
                            if (createdAtLabel.trim().isNotEmpty)
                              Text(
                                "Richiesta: $createdAtLabel",
                                style: AppTextStyles.body,
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _actionLoading
                                        ? null
                                        : () => _reject(staffUserId),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text("Rifiuta"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _actionLoading
                                        ? null
                                        : () => _approve(staffUserId),
                                    child: const Text("Approva"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 18),
                Text(
                  "Staff attivi: ${_members.length}",
                  style: AppTextStyles.pageMessage,
                ),
                const SizedBox(height: 8),
                if (_members.isEmpty)
                  const Text(
                    "Nessun dipendente attivo.",
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  )
                else
                  Column(
                    children: _members.map((m) {
                      final staffUserId = (m["staffUserId"] ?? "").toString();
                      final email = (m["email"] ?? "").toString();
                      final name = (m["name"] ?? "").toString();
                      final approvedAt = (m["approvedAt"] ?? "").toString();
                      final approvedAtLabel = DateFormatIt.dateTimeFromIso(
                        approvedAt,
                      );
                      final title = name.trim().isNotEmpty
                          ? name
                          : (email.isNotEmpty ? email : staffUserId);

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
                            Text(title, style: AppTextStyles.pageMessage),
                            const SizedBox(height: 4),
                            if (email.trim().isNotEmpty)
                              Text("Email: $email", style: AppTextStyles.body),
                            if (approvedAtLabel.trim().isNotEmpty)
                              Text(
                                "Approvato: $approvedAtLabel",
                                style: AppTextStyles.body,
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _actionLoading
                                    ? null
                                    : () => _removeMember(staffUserId),
                                icon: const Icon(
                                  Icons.person_remove_alt_1_outlined,
                                ),
                                label: const Text("Rimuovi"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ],
          ),
          if (_actionLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
