// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'dart:convert';
import '../widgets/base_page.dart';
import '../widgets/app_bottom_nav.dart';
import '../theme/app_text_styles.dart';
import '../widgets/custom_buttons.dart';
import '../widgets/layout/app_body_layout.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/logiche/auth/auth_delete_service.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/requests/purchase_service.dart';
import '../theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tipicooo/hive/hive_profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = false;
  bool _isDeleting = false;
  final AuthDeleteService _deleteService = AuthDeleteService();
  Map<String, String>? _attrs;
  String _payoutMethod = "iban"; // "iban" | "card"
  final TextEditingController _requestedAmountController =
      TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  String? _localAvatarPath;
  Uint8List? _avatarBytes;
  bool _avatarLoading = false;
  final ImagePicker _picker = ImagePicker();
  Future<Map<String, dynamic>?>? _cashbackSummaryFuture;

  @override
  void initState() {
    super.initState();
    _loadAttrsIfLogged();
    _loadLocalAvatar();
    if (AuthState.isUserLoggedIn) {
      _cashbackSummaryFuture = PurchaseService.fetchMySummary();
    }
  }

  Future<void> _loadLocalAvatar() async {
    try {
      await HiveProfile.ensureOpen();
      final v = HiveProfile.loadField('avatar_local_path')?.trim();
      Uint8List? bytes;
      final rawBytes = HiveProfile.loadDynamicField('avatar_bytes');
      if (rawBytes is Uint8List) {
        bytes = rawBytes;
      } else if (rawBytes is List) {
        try {
          bytes = Uint8List.fromList(
            rawBytes.map((e) => (e as num).toInt()).toList(),
          );
        } catch (_) {
          bytes = null;
        }
      }
      final b64 = HiveProfile.loadField('avatar_bytes_b64')?.trim();
      if (bytes == null && b64 != null && b64.isNotEmpty) {
        try {
          bytes = base64Decode(b64);
        } catch (_) {
          bytes = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _localAvatarPath = (v != null && v.isNotEmpty) ? v : null;
        _avatarBytes = bytes;
      });
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    if (_avatarLoading) return;
    setState(() => _avatarLoading = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) {
        if (!mounted) return;
        setState(() => _avatarLoading = false);
        return;
      }
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      await HiveProfile.saveField('avatar_local_path', file.path);
      await HiveProfile.saveField('avatar_bytes', bytes);
      await HiveProfile.saveField('avatar_bytes_b64', b64);
      if (!mounted) return;
      setState(() {
        _localAvatarPath = file.path;
        _avatarBytes = bytes;
        _avatarLoading = false;
      });
    } catch (_) {}
    if (!mounted) return;
    if (_avatarLoading) {
      setState(() => _avatarLoading = false);
    }
  }

  Future<void> _removeAvatar() async {
    await HiveProfile.deleteField('avatar_local_path');
    await HiveProfile.deleteField('avatar_bytes');
    await HiveProfile.deleteField('avatar_bytes_b64');
    if (!mounted) return;
    setState(() {
      _localAvatarPath = null;
      _avatarBytes = null;
    });
  }

  @override
  void dispose() {
    _requestedAmountController.dispose();
    _ibanController.dispose();
    _cardNumberController.dispose();
    super.dispose();
  }

  double _parseRequestedAmount() {
    final raw = _requestedAmountController.text.trim();
    if (raw.isEmpty) return 0;
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  bool get _isRequestedAmountValid => _parseRequestedAmount() >= 50.0;

  String _fmtEuroFromCents(num value) {
    final cents = value.toInt();
    final sign = cents < 0 ? "-" : "";
    final abs = cents.abs();
    final euro = abs ~/ 100;
    final cent = abs % 100;
    return "$sign$euro,${cent.toString().padLeft(2, '0')}";
  }

  Future<void> _loadAttrsIfLogged() async {
    if (!AuthState.isUserLoggedIn) return;
    try {
      final attrs = await AuthService.instance.getUserAttributes();
      if (!mounted) return;
      setState(() => _attrs = attrs);
    } catch (_) {}
  }

  Future<void> _signIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final ok = await AuthService.instance.signInWithHostedUI();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!ok) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
  }

  Future<void> _confirmDelete() async {
    if (_isDeleting) return;
    final reasons = [
      "App inutile",
      "Troppo complicata",
      "Mancano attività utili nella mia zona",
    ];
    String selectedReason = reasons.first;
    final noteController = TextEditingController();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Elimina Profilo", style: AppTextStyles.body),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Prima di eliminarlo, dicci il motivo:",
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 12),
                  for (final r in reasons)
                    RadioListTile<String>(
                      value: r,
                      groupValue: selectedReason,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => selectedReason = v);
                      },
                      title: Text(r),
                      dense: true,
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: "Aggiungi un commento (facoltativo)",
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
                    "Elimina",
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
    setState(() => _isDeleting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
    );

    final deleted = await _deleteService.deleteCurrentUser(
      reason: selectedReason,
      reasonNote: noteController.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop(); // loader
    }

    if (!deleted) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Errore: eliminazione profilo non riuscita. Riprova tra poco.",
          ),
        ),
      );
      return;
    }

    AuthState.setLoggedOut();
    NotificationController.instance.addNotification(
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Profilo eliminato',
        message: 'Il tuo profilo è stato eliminato con successo.',
        timestamp: DateTime.now(),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
      arguments: {'deleted': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: AuthState.isLoggedIn,
      builder: (context, loggedIn, _) {
        final isLoggedIn = loggedIn == true;
        if (isLoggedIn && _attrs == null) {
          // Primo build dopo login: carico gli attributi.
          _loadAttrsIfLogged();
        }
        if (isLoggedIn && _cashbackSummaryFuture == null) {
          _cashbackSummaryFuture = PurchaseService.fetchMySummary();
        }

        if (!isLoggedIn) {
          return BasePage(
            scrollable: false,
            headerTitle: 'Unisciti a noi',
            showBell: false,
            showBack: true,
            showHome: false,
            bottomNavigationBar: const AppBottomNav(currentIndex: 2),
            body: AppBodyLayout(
              children: [
                const Text(
                  "Benvenuto! Scegli come procedere:",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.pageMessage,
                ),
                RoundedYellowButton(
                  label: _isLoading ? "Attendi..." : "Accedi / Registrati",
                  icon: Icons.login,
                  onPressed: _isLoading ? () {} : _signIn,
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          );
        }

        final email = (_attrs?["email"] ?? "").trim();
        final name = (_attrs?["given_name"] ?? "").trim();

        return BasePage(
          scrollable: true,
          headerTitle: 'Il mio profilo',
          showBell: true,
          showBack: true,
          showHome: true,
          showProfile: false,
          showLogout: true,
          onLogout: _logout,
          bottomNavigationBar: const AppBottomNav(currentIndex: 2),
          body: AppBodyLayout(
            children: [
              const SizedBox(height: 10),
              // Avatar (solo UI per ora)
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF2F2F2),
                        border: Border.all(
                          color: const Color(0xFFE7C26A),
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _avatarLoading
                          ? const Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (_avatarBytes != null
                              ? Image.memory(
                                  _avatarBytes!,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.person, size: 50),
                                )
                              : (_localAvatarPath == null
                                  ? const Icon(Icons.person, size: 50)
                                  : (kIsWeb
                                      ? const Icon(Icons.person, size: 50)
                                      : Image.file(
                                          File(_localAvatarPath!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.person, size: 50),
                                        )))),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        BlueNarrowButton(
                          label: "Carica foto",
                          icon: Icons.photo_library_outlined,
                          onPressed: _pickAvatar,
                        ),
                        const SizedBox(height: 12),
                        BlueNarrowButton(
                          label: "Rimuovi foto",
                          icon: Icons.delete_outline,
                          color: Colors.grey.shade700,
                          onPressed:
                              _localAvatarPath == null ? () {} : _removeAvatar,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (name.isNotEmpty)
                Text(
                  name,
                  style: AppTextStyles.sectionTitle,
                  textAlign: TextAlign.center,
                ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  email,
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 30),

              const Text(
                "Inserisci i dati per il rimborso del tuo cashback",
                style: AppTextStyles.pageMessage,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6EF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE7C26A)),
                ),
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _cashbackSummaryFuture,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final totalUserCashbackCents =
                        (data?["totalUserCashbackCents"] ?? 0) as num;
                    return Text(
                      "Totale cashback accumulato: € ${_fmtEuroFromCents(totalUserCashbackCents)}",
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "€ 50,00 valore minimo per la richiesta del cashback",
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6EF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE7C26A)),
                ),
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _cashbackSummaryFuture,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final totalUserCashbackCents =
                        (data?["totalUserCashbackCents"] ?? 0) as num;
                    final hasThreshold = totalUserCashbackCents >= 5000;
                    final canSubmit = hasThreshold && _isRequestedAmountValid;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _requestedAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: "Importo richiesto (€)",
                            hintText: "Es. 50,00",
                            border: const OutlineInputBorder(),
                            errorText:
                                _requestedAmountController.text.trim().isEmpty ||
                                    _isRequestedAmountValid
                                ? null
                                : "Importo non valido: minimo € 50,00.",
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                value: "iban",
                                groupValue: _payoutMethod,
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _payoutMethod = v);
                                },
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  "IBAN",
                                  style: AppTextStyles.body,
                                ),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                value: "card",
                                groupValue: _payoutMethod,
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _payoutMethod = v);
                                },
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  "Carta",
                                  style: AppTextStyles.body,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_payoutMethod == "iban") ...[
                          TextField(
                            controller: _ibanController,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: "IBAN",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ] else ...[
                          TextField(
                            controller: _cardNumberController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Numero carta",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Opacity(
                          opacity: canSubmit ? 1.0 : 0.45,
                          child: AbsorbPointer(
                            absorbing: !canSubmit,
                            child: BlueNarrowButton(
                              label: "Invia richiesta",
                              icon: Icons.send_outlined,
                              onPressed: () {},
                            ),
                          ),
                        ),
                        if (!hasThreshold) ...[
                          const SizedBox(height: 8),
                          const Text(
                            "Pulsante attivo solo da € 50,00 cashback accumulato.",
                            style: AppTextStyles.body,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),
              DangerButton(
                label: _isDeleting ? "Attendi..." : "Elimina Profilo",
                icon: Icons.delete_forever,
                onPressed: _isDeleting ? () {} : _confirmDelete,
              ),
            ],
          ),
        );
      },
    );
  }
}
