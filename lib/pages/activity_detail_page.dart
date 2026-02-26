import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/hive/hive_profile.dart';
import 'package:tipicooo/utils/activity_review_summary.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_text_styles.dart';

class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({
    super.key,
    required this.title,
    required this.address,
    required this.typeLabel,
    required this.description,
    required this.approximate,
    required this.requestId,
    required this.logoKey,
    required this.photoKeys,
    required this.phone,
    required this.email,
    this.reviewSummary,
  });

  final String title;
  final String address;
  final String typeLabel;
  final String description;
  final bool approximate;
  final String requestId;
  final String logoKey;
  final List<String> photoKeys;
  final String phone;
  final String email;
  final Map<String, dynamic>? reviewSummary;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  static const String _favoritesStorageKey = "favorite_activities_v1";
  final ScrollController _scrollController = ScrollController();
  late final Future<String?> _imageUrlFuture;
  late final Future<List<String>> _galleryUrlsFuture;
  late final Future<String> _descriptionFuture;
  late final Future<Map<String, String>> _contactsFuture;
  late final Future<Map<String, dynamic>?> _reviewSummaryFuture;
  bool _isFavorite = false;

  String _fmt1(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

  Widget _buildReviewSection([Map<String, dynamic>? rawOverride]) {
    final raw = rawOverride ?? widget.reviewSummary;
    if (raw == null || raw.isEmpty) return const SizedBox.shrink();
    final summary = ActivityReviewSummary.fromAny(raw);
    if (!summary.hasData) return const SizedBox.shrink();

    final rows = <Widget>[];
    if (summary.avgOverall != null) {
      rows.add(
        Text(
          "Valutazione media: ${_fmt1(summary.avgOverall!)}/10",
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }
    if (summary.recommendedCount > 0) {
      rows.add(
        Text(
          "Consigliato da ${summary.recommendedCount} utenti",
          style: AppTextStyles.body,
        ),
      );
    }
    if (summary.reviewCount > 0) {
      rows.add(
        Text(
          "Recensioni totali: ${summary.reviewCount}",
          style: AppTextStyles.body,
        ),
      );
    }

    void addSubScore(String label, double? value, String fallback) {
      if (value == null) return;
      final l = label.trim().isEmpty ? fallback : label.trim();
      rows.add(Text("$l: ${_fmt1(value)}/10", style: AppTextStyles.body));
    }

    addSubScore(summary.label1, summary.avg1, "Parametro 1");
    addSubScore(summary.label2, summary.avg2, "Parametro 2");
    addSubScore(summary.label3, summary.avg3, "Parametro 3");

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7EACB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD9C08A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Recensioni",
              style: AppTextStyles.pageMessage.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            ...rows,
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Evita che il Future venga ricreato ad ogni rebuild (problema tipico: la
    // descrizione "non appare" perché il fetch riparte continuamente).
    _imageUrlFuture = _loadImageUrl();
    _galleryUrlsFuture = _loadGalleryUrls();
    _descriptionFuture = _loadDescription();
    _contactsFuture = _loadContacts();
    _reviewSummaryFuture = _loadReviewSummary();
    _loadFavoriteState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadReviewSummary() async {
    final fromWidget = widget.reviewSummary;
    if (fromWidget != null && fromWidget.isNotEmpty) {
      final parsed = ActivityReviewSummary.fromAny(fromWidget);
      if (parsed.hasData) return fromWidget;
    }

    final rid = widget.requestId.trim();
    if (rid.isEmpty) return null;

    try {
      final items = await ActivityRequestService.fetchApprovedActivitiesPublic()
          .timeout(const Duration(seconds: 8));
      for (final it in items) {
        final itRid = (it["requestId"] ?? it["id"] ?? "").toString().trim();
        if (itRid != rid) continue;
        final summary = ActivityReviewSummary.fromAny(it).toMapOrNull();
        if (summary != null && summary.isNotEmpty) return summary;
        break;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadFavoriteState() async {
    await HiveProfile.ensureOpen();
    final raw = HiveProfile.loadField(_favoritesStorageKey)?.trim() ?? "";
    if (raw.isEmpty) {
      if (!mounted) return;
      setState(() => _isFavorite = false);
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final exists = decoded.whereType<Map>().any((e) {
        final map = Map<String, dynamic>.from(e);
        final requestId = (map["requestId"] ?? "").toString().trim();
        return requestId == widget.requestId.trim();
      });
      if (!mounted) return;
      setState(() => _isFavorite = exists);
    } catch (_) {}
  }

  String _typeFromWidget() => widget.typeLabel.trim();

  String _cityFromAddress() {
    final parts = widget.address
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) return parts[parts.length - 2];
    if (parts.isNotEmpty) return parts.last;
    return "";
  }

  Future<void> _toggleFavorite() async {
    if (!AuthState.isUserLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Accedi per aggiungere attività ai preferiti."),
        ),
      );
      return;
    }

    await HiveProfile.ensureOpen();
    final raw = HiveProfile.loadField(_favoritesStorageKey)?.trim() ?? "";
    final List<Map<String, dynamic>> favorites = [];
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          favorites.addAll(
            decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          );
        }
      } catch (_) {}
    }

    final noteController = TextEditingController();
    String selectedTag = "work";

    final existingIndex = favorites.indexWhere(
      (e) => (e["requestId"] ?? "").toString().trim() == widget.requestId.trim(),
    );
    if (existingIndex >= 0) {
      final existing = favorites[existingIndex];
      final existingTags = existing["tags"];
      if (existingTags is List && existingTags.isNotEmpty) {
        final first = existingTags.first.toString().trim();
        if (first == "fun" || first == "both" || first == "work") {
          selectedTag = first;
        }
      }
      noteController.text = (existing["note"] ?? "").toString();
    }

    if (!mounted) return;
    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isFavorite ? "Modifica preferito" : "Aggiungi ai preferiti",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: "work",
                          label: Text("Lavoro"),
                          icon: Icon(Icons.work_outline),
                        ),
                        ButtonSegment<String>(
                          value: "fun",
                          label: Text("Divertimento"),
                          icon: Icon(Icons.celebration_outlined),
                        ),
                        ButtonSegment<String>(
                          value: "both",
                          label: Text("Entrambi"),
                          icon: Icon(Icons.auto_awesome_mosaic_outlined),
                        ),
                      ],
                      selected: {selectedTag},
                      onSelectionChanged: (value) {
                        setLocalState(() => selectedTag = value.first);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      maxLength: 180,
                      decoration: const InputDecoration(
                        labelText: "Nota personale (facoltativa)",
                        hintText: "Es. caffè ottimo, carne molto buona...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("Annulla"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("Salva"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirm != true) return;
    final note = noteController.text.trim();
    final tags = <String>[];
    if (selectedTag == "work" || selectedTag == "both") tags.add("work");
    if (selectedTag == "fun" || selectedTag == "both") tags.add("fun");

    final payload = <String, dynamic>{
      "requestId": widget.requestId.trim(),
      "title": widget.title.trim(),
      "activityType": _typeFromWidget(),
      "city": _cityFromAddress(),
      "address": widget.address.trim(),
      "description": widget.description.trim(),
      "logoKey": widget.logoKey.trim(),
      "photoKeys": widget.photoKeys,
      "phone": widget.phone.trim(),
      "email": widget.email.trim(),
      "tags": tags,
      "note": note,
    };

    if (existingIndex >= 0) {
      favorites[existingIndex] = payload;
    } else {
      favorites.add(payload);
    }

    await HiveProfile.saveField(_favoritesStorageKey, jsonEncode(favorites));
    if (!mounted) return;
    setState(() => _isFavorite = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Attività salvata nei preferiti.")),
    );
  }

  Future<String?> _loadImageUrl() async {
    String candidate = widget.logoKey.trim();
    if (candidate.isEmpty && widget.photoKeys.isNotEmpty) {
      candidate = widget.photoKeys.first.trim();
    }
    if (candidate.isEmpty || widget.requestId.trim().isEmpty) return null;
    return ActivityRequestService.fetchPhotoUrl(
      requestId: widget.requestId,
      key: candidate,
    );
  }

  List<String> _visibleMediaKeys() {
    final logo = widget.logoKey.trim();
    final photos = widget.photoKeys
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != logo)
        .toList();

    if (AuthState.isUserLoggedIn) {
      return <String>[if (logo.isNotEmpty) logo, ...photos];
    }

    return <String>[if (logo.isNotEmpty) logo, ...photos.take(3)];
  }

  Future<List<String>> _loadGalleryUrls() async {
    final requestId = widget.requestId.trim();
    if (requestId.isEmpty) return const [];
    final keys = _visibleMediaKeys();
    if (keys.isEmpty) return const [];

    final urls = <String>[];
    for (final key in keys) {
      final url = await ActivityRequestService.fetchPhotoUrl(
        requestId: requestId,
        key: key,
      );
      final clean = (url ?? "").trim();
      if (clean.isNotEmpty) urls.add(clean);
    }
    return urls;
  }

  Future<String> _loadDescription() async {
    final local = widget.description.trim();
    if (local.isNotEmpty) return local;

    final rid = widget.requestId.trim();
    if (rid.isEmpty) return "";

    // Fallback: la mappa potrebbe avere dati cache/vecchi. Rileggiamo dal pubblico.
    try {
      final items = await ActivityRequestService.fetchApprovedActivitiesPublic()
          .timeout(const Duration(seconds: 8));
      for (final it in items) {
        final itRid = (it["requestId"] ?? it["id"] ?? "").toString().trim();
        if (itRid != rid) continue;
        final d =
            (it["descrizione"] ??
                    it["description"] ??
                    it["descrizione_attivita"] ??
                    it["descrizioneAttivita"] ??
                    "")
                .toString()
                .trim();
        return d;
      }
    } catch (e) {
      // Ignora: la descrizione resta nascosta se non disponibile.
    }

    return "";
  }

  Future<Map<String, String>> _loadContacts() async {
    var phone = widget.phone.trim();
    var email = widget.email.trim();
    if (phone.isNotEmpty && email.isNotEmpty) {
      return {"phone": phone, "email": email};
    }

    final rid = widget.requestId.trim();
    if (rid.isEmpty) return {"phone": phone, "email": email};

    try {
      final items = await ActivityRequestService.fetchApprovedActivitiesPublic()
          .timeout(const Duration(seconds: 8));
      for (final it in items) {
        final itRid = (it["requestId"] ?? it["id"] ?? "").toString().trim();
        if (itRid != rid) continue;

        if (phone.isEmpty) {
          phone = (it["telefono"] ?? it["phone"] ?? it["tel"] ?? "")
              .toString()
              .trim();
        }
        if (email.isEmpty) {
          email =
              (it["email"] ??
                      it["mail"] ??
                      it["Email"] ??
                      it["e_mail"] ??
                      it["emailAddress"] ??
                      it["pec"] ??
                      "")
                  .toString()
                  .trim();
        }
        break;
      }
    } catch (_) {}

    return {"phone": phone, "email": email};
  }

  String _normalizePhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return "";
    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      final ch = trimmed[i];
      final isDigit = ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
      if (isDigit || (ch == '+' && buffer.isEmpty)) {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  // ignore: unused_element
  Future<void> _callPhone(BuildContext context) async {
    final normalized = _normalizePhone(widget.phone);
    if (normalized.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: normalized);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossibile avviare la chiamata.")),
      );
    }
  }

  Future<void> _sendEmail(BuildContext context, [String? value]) async {
    final email = (value ?? widget.email).trim();
    if (email.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: email);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossibile aprire l'email.")),
      );
    }
  }

  Future<void> _openDirections(BuildContext context) async {
    if (!AuthState.isUserLoggedIn) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Devi essere loggato per aprire la mappa."),
          ),
        );
      }
      return;
    }

    final destination = widget.address.trim().isNotEmpty
        ? widget.address.trim()
        : widget.title.trim();
    if (destination.isEmpty) return;

    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}",
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossibile aprire Google Maps.")),
      );
    }
  }

  void _openImageViewer(List<String> urls, int initialIndex) {
    if (urls.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ActivityImageViewerPage(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scheda attivita"),
        actions: [
          IconButton(
            tooltip: _isFavorite ? "Modifica preferito" : "Aggiungi ai preferiti",
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF0),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD9C08A)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAD9B6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD9C08A)),
                        ),
                        child: FutureBuilder<String?>(
                          future: _imageUrlFuture,
                          builder: (context, snapshot) {
                            final imageUrl = snapshot.data;
                            if (imageUrl == null || imageUrl.isEmpty) {
                              return const Icon(
                                Icons.store,
                                color: Color(0xFF8A6A3D),
                                size: 34,
                              );
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return const Icon(
                                    Icons.store,
                                    color: Color(0xFF8A6A3D),
                                    size: 34,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.typeLabel.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1E2C3),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  widget.typeLabel,
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 12,
                                    color: const Color(0xFF7A5B2F),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              widget.title,
                              style: AppTextStyles.pageMessage.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (AuthState.isUserLoggedIn)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.createPurchase,
                            arguments: {
                              "activityRequestId": widget.requestId,
                              "activityTitle": widget.title,
                            },
                          );
                        },
                        icon: const Icon(Icons.receipt_long),
                        label: const Text("Registra pagamento (cashback)"),
                      ),
                    ),
                  if (widget.address.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.place,
                          size: 18,
                          color: Color(0xFF8A6A3D),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.address,
                            style: AppTextStyles.body,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (AuthState.isUserLoggedIn) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openDirections(context),
                        icon: const Icon(Icons.directions),
                        label: const Text("Come raggiungerci"),
                      ),
                    ),
                  ],
                  FutureBuilder<String>(
                    future: _descriptionFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            "Caricamento descrizione...",
                            style: AppTextStyles.body,
                          ),
                        );
                      }
                      final d = (snapshot.data ?? "").trim();
                      if (d.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          d,
                          style: AppTextStyles.body.copyWith(height: 1.35),
                        ),
                      );
                    },
                  ),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _reviewSummaryFuture,
                    builder: (context, snapshot) {
                      return _buildReviewSection(snapshot.data);
                    },
                  ),
                  FutureBuilder<List<String>>(
                    future: _galleryUrlsFuture,
                    builder: (context, snapshot) {
                      final urls = snapshot.data ?? const <String>[];
                      if (urls.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                          height: 86,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: urls.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final imageUrl = urls[index];
                              return GestureDetector(
                                onTap: () => _openImageViewer(urls, index),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    imageUrl,
                                    width: 86,
                                    height: 86,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 86,
                                      height: 86,
                                      color: const Color(0xFFEAD9B6),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.photo,
                                        color: Color(0xFF8A6A3D),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  FutureBuilder<Map<String, String>>(
                    future: _contactsFuture,
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? const <String, String>{};
                      final phone = (data["phone"] ?? widget.phone).trim();
                      final email = (data["email"] ?? widget.email).trim();
                      if (phone.isEmpty && email.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.phone,
                                  size: 18,
                                  color: Color(0xFF8A6A3D),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        "Per informazioni o prenotazioni: ",
                                        style: AppTextStyles.body.copyWith(
                                          height: 1.35,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => launchUrl(
                                          Uri(
                                            scheme: 'tel',
                                            path: _normalizePhone(phone),
                                          ),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                        child: Text(
                                          phone,
                                          style: AppTextStyles.body.copyWith(
                                            height: 1.35,
                                            decoration:
                                                TextDecoration.underline,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.email_outlined,
                                  size: 18,
                                  color: Color(0xFF8A6A3D),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        "Email: ",
                                        style: AppTextStyles.body.copyWith(
                                          height: 1.35,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _sendEmail(context, email),
                                        child: Text(
                                          email,
                                          style: AppTextStyles.body.copyWith(
                                            height: 1.35,
                                            decoration:
                                                TextDecoration.underline,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  if (widget.approximate) ...[
                    const SizedBox(height: 10),
                    const Text(
                      "Posizione indicativa: precisa in aggiornamento.",
                      style: AppTextStyles.body,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityImageViewerPage extends StatefulWidget {
  const _ActivityImageViewerPage({
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_ActivityImageViewerPage> createState() =>
      _ActivityImageViewerPageState();
}

class _ActivityImageViewerPageState extends State<_ActivityImageViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text("${_currentIndex + 1}/${widget.imageUrls.length}"),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                widget.imageUrls[index],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 42,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
