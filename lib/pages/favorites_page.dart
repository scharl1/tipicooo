import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tipicooo/hive/hive_profile.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/pages/activity_detail_page.dart';
import '../widgets/base_page.dart';
import '../widgets/app_bottom_nav.dart';
import '../theme/app_text_styles.dart';
import '../widgets/layout/app_body_layout.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  static const String _storageKey = "favorite_activities_v1";

  final TextEditingController _searchController = TextEditingController();
  final List<_FavoriteActivity> _favorites = [];
  List<Map<String, dynamic>> _allActivities = [];
  bool _loading = true;
  String _searchQuery = "";
  String _typeFilter = "";
  String _cityFilter = "";
  _FavoriteScope _scope = _FavoriteScope.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q == _searchQuery) return;
      setState(() => _searchQuery = q);
    });
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await HiveProfile.ensureOpen();
    await _loadFavorites();
    await _loadActivities();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadFavorites() async {
    final raw = HiveProfile.loadField(_storageKey)?.trim() ?? "";
    if (raw.isEmpty) {
      _favorites.clear();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _favorites.clear();
        return;
      }
      _favorites
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map((e) => _FavoriteActivity.fromJson(Map<String, dynamic>.from(e))),
        );
    } catch (_) {
      _favorites.clear();
    }
  }

  Future<void> _saveFavorites() async {
    final data = _favorites.map((e) => e.toJson()).toList();
    await HiveProfile.saveField(_storageKey, jsonEncode(data));
  }

  Future<void> _loadActivities() async {
    try {
      final items = await ActivityRequestService.fetchApprovedActivitiesPublic();
      _allActivities = items;
    } catch (_) {
      _allActivities = [];
    }
  }

  String _titleFromItem(Map<String, dynamic> item) {
    final insegna = (item["insegna"] ?? "").toString().trim();
    final ragione = (item["ragione_sociale"] ?? "").toString().trim();
    final id = (item["requestId"] ?? item["id"] ?? "").toString().trim();
    if (insegna.isNotEmpty) return insegna;
    if (ragione.isNotEmpty) return ragione;
    if (id.isNotEmpty) return id;
    return "Attività";
  }

  String _typeFromItem(Map<String, dynamic> item) {
    return (item["tipo_attivita"] ?? item["categoria"] ?? "")
        .toString()
        .trim();
  }

  String _cityFromItem(Map<String, dynamic> item) {
    return (item["citta"] ?? item["city"] ?? "").toString().trim();
  }

  String _addressFromItem(Map<String, dynamic> item) {
    final via = (item["via"] ?? "").toString().trim();
    final civico = (item["numero_civico"] ?? "").toString().trim();
    final cap = (item["cap"] ?? "").toString().trim();
    final city = _cityFromItem(item);
    final province = (item["provincia"] ?? "").toString().trim();
    final pieces = <String>[
      [via, civico].where((e) => e.isNotEmpty).join(" "),
      [cap, city].where((e) => e.isNotEmpty).join(" "),
      province,
    ].where((e) => e.trim().isNotEmpty);
    final composed = pieces.join(", ").trim();
    if (composed.isNotEmpty) return composed;
    return (item["location"]?["label"] ?? "").toString().trim();
  }

  String _descriptionFromItem(Map<String, dynamic> item) {
    return (item["descrizione"] ?? item["description"] ?? "")
        .toString()
        .trim();
  }

  List<String> _photoKeysFromItem(Map<String, dynamic> item) {
    final raw = item["photoKeys"];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }

  List<String> get _availableTypes {
    final set = <String>{};
    for (final it in _allActivities) {
      final t = _typeFromItem(it);
      if (t.isNotEmpty) set.add(t);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _availableCities {
    final set = <String>{};
    for (final it in _allActivities) {
      if (_typeFilter.isNotEmpty &&
          !_typeFromItem(it).toLowerCase().contains(_typeFilter.toLowerCase())) {
        continue;
      }
      final c = _cityFromItem(it);
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return list;
  }

  bool _matchesFilters(Map<String, dynamic> it) {
    final title = _titleFromItem(it).toLowerCase();
    final type = _typeFromItem(it).toLowerCase();
    final city = _cityFromItem(it).toLowerCase();
    final query = _searchQuery.toLowerCase();

    if (_typeFilter.isNotEmpty && !type.contains(_typeFilter.toLowerCase())) {
      return false;
    }
    if (_cityFilter.isNotEmpty && !city.contains(_cityFilter.toLowerCase())) {
      return false;
    }
    if (query.isNotEmpty &&
        !title.contains(query) &&
        !type.contains(query) &&
        !city.contains(query)) {
      return false;
    }
    return true;
  }

  List<Map<String, dynamic>> get _candidateActivities {
    final out = _allActivities.where(_matchesFilters).toList();
    out.sort((a, b) => _titleFromItem(a).compareTo(_titleFromItem(b)));
    return out;
  }

  List<_FavoriteActivity> get _filteredFavorites {
    final out = _favorites.where((f) {
      if (_scope == _FavoriteScope.work && !f.tags.contains("work")) {
        return false;
      }
      if (_scope == _FavoriteScope.fun && !f.tags.contains("fun")) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return f.title.toLowerCase().contains(q) ||
          f.activityType.toLowerCase().contains(q) ||
          f.city.toLowerCase().contains(q);
    }).toList();
    out.sort((a, b) => a.title.compareTo(b.title));
    return out;
  }

  bool _isAlreadyFavorite(String requestId) {
    return _favorites.any((f) => f.requestId == requestId);
  }

  Future<void> _addFavorite(Map<String, dynamic> item) async {
    final requestId = (item["requestId"] ?? item["id"] ?? "").toString().trim();
    if (requestId.isEmpty) return;

    final noteController = TextEditingController();
    String selectedTag = "work";
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
                    const Text(
                      "Salva preferito",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                        hintText:
                            "Es. caffè ottimo, carne molto buona, parcheggio comodo...",
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

    final existingIndex = _favorites.indexWhere((f) => f.requestId == requestId);
    if (existingIndex >= 0) {
      final existing = _favorites[existingIndex];
      final tags = {...existing.tags};
      if (selectedTag == "work" || selectedTag == "both") tags.add("work");
      if (selectedTag == "fun" || selectedTag == "both") tags.add("fun");
      _favorites[existingIndex] = existing.copyWith(
        tags: tags.toList(),
        note: note,
      );
    } else {
      final tags = <String>[];
      if (selectedTag == "work" || selectedTag == "both") tags.add("work");
      if (selectedTag == "fun" || selectedTag == "both") tags.add("fun");

      _favorites.add(
        _FavoriteActivity(
          requestId: requestId,
          title: _titleFromItem(item),
          activityType: _typeFromItem(item),
          city: _cityFromItem(item),
          address: _addressFromItem(item),
          description: _descriptionFromItem(item),
          logoKey: (item["logo"] ?? "").toString().trim(),
          photoKeys: _photoKeysFromItem(item),
          phone: (item["telefono"] ?? "").toString().trim(),
          email: (item["email"] ?? "").toString().trim(),
          tags: tags,
          note: note,
        ),
      );
    }

    await _saveFavorites();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Attività salvata nei preferiti.")),
    );
  }

  Future<void> _removeFavorite(_FavoriteActivity fav) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.work_outline),
                title: const Text("Rimuovi solo da Lavoro"),
                onTap: () => Navigator.of(context).pop("work"),
              ),
              ListTile(
                leading: const Icon(Icons.celebration_outlined),
                title: const Text("Rimuovi solo da Divertimento"),
                onTap: () => Navigator.of(context).pop("fun"),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text("Rimuovi da tutti i preferiti"),
                onTap: () => Navigator.of(context).pop("all"),
              ),
            ],
          ),
        );
      },
    );
    if (action == null) return;

    final idx = _favorites.indexWhere((e) => e.requestId == fav.requestId);
    if (idx < 0) return;
    final current = _favorites[idx];

    if (action == "all") {
      _favorites.removeAt(idx);
    } else {
      final tags = current.tags.where((t) => t != action).toList();
      if (tags.isEmpty) {
        _favorites.removeAt(idx);
      } else {
        _favorites[idx] = current.copyWith(tags: tags);
      }
    }

    await _saveFavorites();
    if (!mounted) return;
    setState(() {});
  }

  void _openDetail(_FavoriteActivity f) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          title: f.title,
          address: f.address,
          typeLabel: f.activityType,
          description: f.description,
          approximate: false,
          requestId: f.requestId,
          logoKey: f.logoKey,
          photoKeys: f.photoKeys,
          phone: f.phone,
          email: f.email,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: AuthState.isLoggedIn,
      builder: (context, loggedIn, _) {
        final isLoggedIn = loggedIn == true;
        final candidates = _candidateActivities;
        final favorites = _filteredFavorites;

        return BasePage(
          scrollable: true,
          headerTitle: 'Preferiti',
          showBack: true,
          showHome: false,
          showBell: false,
          showProfile: true,
          onRefresh: isLoggedIn ? _init : null,
          bottomNavigationBar: const AppBottomNav(currentIndex: 1),
          body: AppBodyLayout(
            children: [
              if (!isLoggedIn) ...[
                const Text(
                  "Accedi per vedere e salvare le tue attività preferite.",
                  style: AppTextStyles.pageMessage,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.profile),
                  icon: const Icon(Icons.login),
                  label: const Text("Accedi / Registrati"),
                ),
              ] else ...[
                const Text(
                  "Salva attività preferite per Lavoro o Divertimento e ritrovale subito.",
                  style: AppTextStyles.pageMessage,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                _buildScopeSelector(),
                const SizedBox(height: 14),
                _buildFiltersCard(),
                const SizedBox(height: 14),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _buildCandidatesSection(candidates),
                  const SizedBox(height: 14),
                  _buildFavoritesSection(favorites),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildScopeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text("Tutti"),
          selected: _scope == _FavoriteScope.all,
          onSelected: (_) => setState(() => _scope = _FavoriteScope.all),
        ),
        ChoiceChip(
          label: const Text("Lavoro"),
          selected: _scope == _FavoriteScope.work,
          onSelected: (_) => setState(() => _scope = _FavoriteScope.work),
        ),
        ChoiceChip(
          label: const Text("Divertimento"),
          selected: _scope == _FavoriteScope.fun,
          onSelected: (_) => setState(() => _scope = _FavoriteScope.fun),
        ),
      ],
    );
  }

  Widget _buildFiltersCard() {
    final types = _availableTypes;
    final cities = _availableCities;
    final typeValue = _typeFilter.isEmpty ? "__all__" : _typeFilter;
    final cityValue = _cityFilter.isEmpty ? "__all__" : _cityFilter;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Scegli attività da aggiungere",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: "Ricerca",
              hintText: "Nome attività, tipo o città",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownMenu<String>(
                  initialSelection: typeValue,
                  label: const Text("Tipo attività"),
                  dropdownMenuEntries: [
                    const DropdownMenuEntry<String>(
                      value: "__all__",
                      label: "Tutti i tipi",
                    ),
                    ...types.map(
                      (t) => DropdownMenuEntry<String>(value: t, label: t),
                    ),
                  ],
                  onSelected: (v) {
                    setState(() {
                      _typeFilter = (v == null || v == "__all__") ? "" : v;
                      _cityFilter = "";
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownMenu<String>(
                  initialSelection: cityValue,
                  label: const Text("Città"),
                  dropdownMenuEntries: [
                    const DropdownMenuEntry<String>(
                      value: "__all__",
                      label: "Tutte le città",
                    ),
                    ...cities.map(
                      (c) => DropdownMenuEntry<String>(value: c, label: c),
                    ),
                  ],
                  onSelected: (v) {
                    setState(() {
                      _cityFilter = (v == null || v == "__all__") ? "" : v;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCandidatesSection(List<Map<String, dynamic>> candidates) {
    return Container(
      width: double.infinity,
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
            "Attività trovate (${candidates.length})",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (candidates.isEmpty)
            const Text(
              "Nessuna attività con questi filtri.",
              style: TextStyle(color: Colors.black54),
            )
          else
            ...candidates.take(40).map((it) {
              final requestId =
                  (it["requestId"] ?? it["id"] ?? "").toString().trim();
              final title = _titleFromItem(it);
              final type = _typeFromItem(it);
              final city = _cityFromItem(it);
              final already = _isAlreadyFavorite(requestId);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(title),
                  subtitle: Text(
                    [if (type.isNotEmpty) type, if (city.isNotEmpty) city]
                        .join(" • "),
                  ),
                  trailing: OutlinedButton.icon(
                    onPressed: requestId.isEmpty ? null : () => _addFavorite(it),
                    icon: Icon(already ? Icons.edit_outlined : Icons.favorite_border),
                    label: Text(already ? "Modifica" : "Salva"),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFavoritesSection(List<_FavoriteActivity> favorites) {
    return Container(
      width: double.infinity,
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
            "I tuoi preferiti (${favorites.length})",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (favorites.isEmpty)
            const Text(
              "Nessun preferito salvato per questo filtro.",
              style: TextStyle(color: Colors.black54),
            )
          else
            ...favorites.map((f) {
              final chips = <Widget>[
                if (f.tags.contains("work"))
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text("Lavoro"),
                  ),
                if (f.tags.contains("fun"))
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text("Divertimento"),
                  ),
              ];

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => _openDetail(f),
                  title: Text(f.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (f.activityType.isNotEmpty) f.activityType,
                          if (f.city.isNotEmpty) f.city,
                        ].join(" • "),
                      ),
                      if (f.note.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Nota: ${f.note.trim()}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: chips),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeFavorite(f),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

enum _FavoriteScope { all, work, fun }

class _FavoriteActivity {
  _FavoriteActivity({
    required this.requestId,
    required this.title,
    required this.activityType,
    required this.city,
    required this.address,
    required this.description,
    required this.logoKey,
    required this.photoKeys,
    required this.phone,
    required this.email,
    required this.tags,
    required this.note,
  });

  final String requestId;
  final String title;
  final String activityType;
  final String city;
  final String address;
  final String description;
  final String logoKey;
  final List<String> photoKeys;
  final String phone;
  final String email;
  final List<String> tags;
  final String note;

  _FavoriteActivity copyWith({List<String>? tags, String? note}) {
    return _FavoriteActivity(
      requestId: requestId,
      title: title,
      activityType: activityType,
      city: city,
      address: address,
      description: description,
      logoKey: logoKey,
      photoKeys: photoKeys,
      phone: phone,
      email: email,
      tags: tags ?? this.tags,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    "requestId": requestId,
    "title": title,
    "activityType": activityType,
    "city": city,
    "address": address,
    "description": description,
    "logoKey": logoKey,
    "photoKeys": photoKeys,
    "phone": phone,
    "email": email,
    "tags": tags,
    "note": note,
  };

  factory _FavoriteActivity.fromJson(Map<String, dynamic> json) {
    final rawTags = json["tags"];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    return _FavoriteActivity(
      requestId: (json["requestId"] ?? "").toString().trim(),
      title: (json["title"] ?? "").toString().trim(),
      activityType: (json["activityType"] ?? "").toString().trim(),
      city: (json["city"] ?? "").toString().trim(),
      address: (json["address"] ?? "").toString().trim(),
      description: (json["description"] ?? "").toString().trim(),
      logoKey: (json["logoKey"] ?? "").toString().trim(),
      photoKeys: (json["photoKeys"] is List)
          ? (json["photoKeys"] as List)
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : const [],
      phone: (json["phone"] ?? "").toString().trim(),
      email: (json["email"] ?? "").toString().trim(),
      tags: tags,
      note: (json["note"] ?? "").toString().trim(),
    );
  }
}
