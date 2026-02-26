import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:tipicooo/activity/activities_service.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/pages/activity_detail_page.dart';
import 'package:tipicooo/utils/activity_review_summary.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/base_page.dart';
import '../widgets/app_bottom_nav.dart';
import '../theme/app_text_styles.dart';
import '../widgets/layout/app_body_layout.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late Future<List<_ActivityMapPoint>> _mapPointsFuture;
  final Map<String, LatLng> _geocodingCache = {};
  final Map<String, Future<String?>> _imageUrlCache = {};
  final Map<String, Future<List<String>>> _galleryUrlCache = {};
  final TextEditingController _activityTypeController =
      TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  bool? _lastAuthValue;
  String _activityTypeQuery = '';
  String _cityQuery = '';
  String _appliedActivityTypeQuery = '';
  String _appliedCityQuery = '';
  List<String> _activityTypeOptions = const [];
  List<String> _cityOptions = const [];
  List<_ActivityMapPoint> _allPointsCache = const [];
  bool _selectForPayment = false;
  bool _routeArgsLoaded = false;

  @override
  void initState() {
    super.initState();
    _mapPointsFuture = _loadMapPoints();
    _lastAuthValue = AuthState.isLoggedIn.value;
    AuthState.isLoggedIn.addListener(_onAuthChanged);
    _activityTypeController.addListener(_onActivityTypeTextChanged);
    _cityController.addListener(_onCityTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsLoaded) return;
    _routeArgsLoaded = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _selectForPayment = args["selectForPayment"] == true;
    }
  }

  @override
  void dispose() {
    AuthState.isLoggedIn.removeListener(_onAuthChanged);
    _activityTypeController.removeListener(_onActivityTypeTextChanged);
    _cityController.removeListener(_onCityTextChanged);
    _activityTypeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _onActivityTypeTextChanged() {
    final value = _activityTypeController.text.trim();
    if (value == _activityTypeQuery) return;
    setState(() {
      _activityTypeQuery = value;
      _cityQuery = '';
      _cityController.clear();
      _cityOptions = _computeCityOptionsForTypeQuery(_activityTypeQuery);
    });
  }

  void _onCityTextChanged() {
    final value = _cityController.text.trim();
    if (value == _cityQuery) return;
    setState(() {
      _cityQuery = value;
    });
  }

  void _onAuthChanged() {
    final current = AuthState.isLoggedIn.value;
    if (current == _lastAuthValue) return;
    _lastAuthValue = current;
    _refreshMapPoints();
  }

  Future<void> _refreshMapPoints() async {
    setState(() {
      _mapPointsFuture = _loadMapPoints();
    });
  }

  void _openFullScreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenMapPage(
          loadPoints: _loadMapPoints,
          selectForPayment: _selectForPayment,
        ),
      ),
    );
  }

  void _openActivityDetail(_ActivityMapPoint point) {
    if (_selectForPayment) {
      Navigator.pushNamed(
        context,
        AppRoutes.createPurchase,
        arguments: {
          "activityRequestId": point.requestId,
          "activityTitle": point.title,
        },
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          title: point.title,
          address: point.address,
          typeLabel: point.activityType,
          description: point.description,
          approximate: point.approximate,
          requestId: point.requestId,
          logoKey: point.logoKey,
          photoKeys: point.photoKeys,
          phone: point.phone,
          email: point.email,
          reviewSummary: point.reviewSummary,
        ),
      ),
    );
  }

  Future<List<_ActivityMapPoint>> _loadMapPoints() async {
    final sourceItems = <Map<String, dynamic>>[];
    final publicItems = <Map<String, dynamic>>[];

    if (AuthState.isUserLoggedIn) {
      // Sorgente primaria: endpoint approved autenticato.
      final approvedItems =
          await ActivityRequestService.fetchApprovedActivities();
      sourceItems.addAll(approvedItems.where(_isConfirmedItem));
      // Per campi non sensibili (logo, foto, telefono) integriamo dal pubblico.
      final pub = await ActivityRequestService.fetchApprovedActivitiesPublic();
      publicItems.addAll(pub.where(_isConfirmedItem));
    }

    // Sorgente pubblica per utente anonimo o come fallback.
    if (sourceItems.isEmpty) {
      final pub = await ActivityRequestService.fetchApprovedActivitiesPublic();
      publicItems.addAll(pub.where(_isConfirmedItem));
      sourceItems.addAll(publicItems.where(_isConfirmedItem));
    }

    // Fallback legacy non-web.
    if (sourceItems.isEmpty && !kIsWeb) {
      final publicRaw = await ActivitiesService.instance.getActivities();
      final legacyItems = _normalizeItems(publicRaw);
      sourceItems.addAll(legacyItems.where(_isConfirmedItem));
    }

    final dedupedItems = <String, Map<String, dynamic>>{};
    for (final item in sourceItems) {
      final key = (item["requestId"] ?? item["id"] ?? "").toString();
      if (key.isEmpty) {
        dedupedItems["fallback_${dedupedItems.length}"] = item;
      } else {
        dedupedItems[key] = item;
      }
    }

    final points = <_ActivityMapPoint>[];
    final types = <String>{};

    // Indicizza gli item pubblici sia per requestId che per id.
    final publicById = <String, Map<String, dynamic>>{};
    for (final item in publicItems) {
      final rid = (item["requestId"] ?? "").toString().trim();
      final id = (item["id"] ?? "").toString().trim();
      if (rid.isNotEmpty) publicById[rid] = item;
      if (id.isNotEmpty) publicById[id] = item;
    }

    for (var item in dedupedItems.values) {
      final requestId = (item["requestId"] ?? item["id"] ?? "").toString();
      final baseDescription = _descriptionFromItem(item);
      if (requestId.isNotEmpty) {
        final publicItem = publicById[requestId];
        if (publicItem != null) {
          // Merge "prefer non-empty": non sovrascrivere campi pubblici con stringhe vuote.
          final merged = <String, dynamic>{...publicItem};
          item.forEach((k, v) {
            final existing = merged[k];
            if (v == null && existing != null) return;
            if (v is String) {
              if (v.trim().isEmpty &&
                  existing is String &&
                  existing.trim().isNotEmpty) {
                return;
              }
            }
            if (v is List) {
              if (v.isEmpty && existing is List && existing.isNotEmpty) return;
            }
            merged[k] = v;
          });
          item = merged;
        }
      }
      final currentAddress = _addressFromItem(item);
      if (currentAddress.isEmpty &&
          requestId.isNotEmpty &&
          AuthState.isUserLoggedIn) {
        final detail = await ActivityRequestService.fetchRequestDetail(
          requestId,
        );
        if (detail != null) {
          item = <String, dynamic>{...item, ...detail};
        }
      }

      final title = _titleFromItem(item);
      final address = _addressFromItem(item);
      final id = (item["id"] ?? item["requestId"] ?? title).toString();
      final activityType = _activityTypeFromItem(item);
      final city = _cityFromItem(item);
      var description = _descriptionFromItem(item);
      if (description.isEmpty) description = baseDescription;
      final logoKey = _logoKeyFromItem(item);
      final photoKeys = _photoKeysFromItem(item);
      final phone = _phoneFromItem(item);
      final email = _emailFromItem(item);
      final reviewSummary = ActivityReviewSummary.fromAny(item).toMapOrNull();
      if (activityType.isNotEmpty) {
        types.add(activityType);
      }

      final direct = _extractLatLng(item);
      final resolvedPoint = direct ?? _fallbackLatLngFor(id);

      points.add(
        _ActivityMapPoint(
          id: id,
          requestId: requestId,
          title: title,
          address: address,
          activityType: activityType,
          city: city,
          description: description,
          logoKey: logoKey,
          photoKeys: photoKeys,
          phone: phone,
          email: email,
          reviewSummary: reviewSummary,
          latLng: resolvedPoint,
          approximate: direct == null,
        ),
      );
    }

    debugPrint(
      "[SearchMap] source=${sourceItems.length} deduped=${dedupedItems.length} points=${points.length}",
    );

    final sortedTypes = types.toList()..sort();
    if (mounted) {
      setState(() {
        _allPointsCache = points;
        _activityTypeOptions = sortedTypes;
        if (_activityTypeQuery.isEmpty && sortedTypes.length == 1) {
          _activityTypeQuery = sortedTypes.first;
          _activityTypeController.text = _activityTypeQuery;
        }
        final hasMatchingType = _activityTypeOptions.any(
          (e) => e.toLowerCase().contains(_activityTypeQuery.toLowerCase()),
        );
        if (_activityTypeQuery.isNotEmpty && !hasMatchingType) {
          _activityTypeQuery = '';
          _activityTypeController.clear();
        }
        _cityOptions = _computeCityOptionsForTypeQuery(_activityTypeQuery);
        if (_cityQuery.isEmpty && _cityOptions.length == 1) {
          _cityQuery = _cityOptions.first;
          _cityController.text = _cityQuery;
        }
        final hasMatchingCity = _cityOptions.any(
          (e) => e.toLowerCase().contains(_cityQuery.toLowerCase()),
        );
        if (_cityQuery.isNotEmpty && !hasMatchingCity) {
          _cityQuery = '';
          _cityController.clear();
        }
      });
    }
    return points;
  }

  bool _isConfirmedItem(Map<String, dynamic> item) {
    if (_isDeletedItem(item)) return false;
    final raw = (item["status"] ?? item["stato"] ?? "")
        .toString()
        .trim()
        .toLowerCase();
    if (raw.isEmpty) return false;
    final isApproved =
        raw == "approved" ||
        raw == "confirm" ||
        raw == "confirmed" ||
        raw == "confermata" ||
        raw == "confermato";
    if (!isApproved) return false;
    return _isPublicReady(item);
  }

  bool _isDeletedItem(Map<String, dynamic> item) {
    final deletedAt = (item["deletedAt"] ?? item["deleted_at"] ?? "")
        .toString()
        .trim();
    if (deletedAt.isNotEmpty) return true;

    final status = (item["status"] ?? item["stato"] ?? "")
        .toString()
        .trim()
        .toLowerCase();
    if (status == "deleted" || status == "removed" || status == "archived") {
      return true;
    }

    final isDeletedRaw = item["isDeleted"] ?? item["deleted"] ?? false;
    if (isDeletedRaw == true) return true;
    if (isDeletedRaw is String && isDeletedRaw.toLowerCase() == "true") {
      return true;
    }
    return false;
  }

  bool _isPublicReady(Map<String, dynamic> item) {
    final logo = (item["logo"] ?? item["logoKey"] ?? "").toString().trim();
    if (logo.isEmpty) return false;
    final rawPhotoKeys =
        item["photoKeys"] ?? item["photo_keys"] ?? item["photos"];
    if (rawPhotoKeys is List) {
      final count = rawPhotoKeys
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .length;
      return count >= 5;
    }
    return false;
  }

  List<Map<String, dynamic>> _normalizeItems(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is Map && raw["items"] is List) {
      return (raw["items"] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  String _titleFromItem(Map<String, dynamic> item) {
    final insegna = (item["insegna"] ?? item["insegnaNome"] ?? "")
        .toString()
        .trim();
    final ragione = (item["ragione_sociale"] ?? item["ragioneSociale"] ?? "")
        .toString()
        .trim();
    if (insegna.isNotEmpty) return insegna;
    if (ragione.isNotEmpty) return ragione;
    return (item["requestId"] ?? item["id"] ?? "Attivita").toString();
  }

  String _addressFromItem(Map<String, dynamic> item) {
    final via = (item["via"] ?? item["indirizzo"] ?? item["street"] ?? "")
        .toString()
        .trim();
    final numero = (item["numero_civico"] ?? item["numeroCivico"] ?? "")
        .toString()
        .trim();
    final citta = (item["citta"] ?? item["cittaComune"] ?? item["city"] ?? "")
        .toString()
        .trim();
    final provincia = (item["provincia"] ?? item["province"] ?? "")
        .toString()
        .trim();
    final cap = (item["cap"] ?? "").toString().trim();
    final paese = (item["paese"] ?? item["country"] ?? "").toString().trim();

    final line1 = [via, numero].where((e) => e.isNotEmpty).join(" ");
    final line2 = [cap, citta, provincia].where((e) => e.isNotEmpty).join(" ");
    final parts = <String>[
      if (line1.isNotEmpty) line1,
      if (line2.isNotEmpty) line2,
      if (paese.isNotEmpty) paese else "Italia",
    ];
    return parts.join(", ");
  }

  String _activityTypeFromItem(Map<String, dynamic> item) {
    return (item["tipo_attivita"] ??
            item["categoria"] ??
            item["activity_type"] ??
            "")
        .toString()
        .trim();
  }

  String _cityFromItem(Map<String, dynamic> item) {
    return (item["citta"] ?? item["cittaComune"] ?? item["city"] ?? "")
        .toString()
        .trim();
  }

  List<String> _computeCityOptionsForTypeQuery(String typeQuery) {
    final type = typeQuery.trim().toLowerCase();
    if (type.isEmpty) return const [];
    final cities = <String>{};
    for (final point in _allPointsCache) {
      if (!point.activityType.trim().toLowerCase().contains(type)) continue;
      final city = point.city.trim();
      if (city.isNotEmpty) cities.add(city);
    }
    final sorted = cities.toList()..sort();
    return sorted;
  }

  String _descriptionFromItem(Map<String, dynamic> item) {
    return (item["descrizione"] ?? item["description"] ?? "").toString().trim();
  }

  String _logoKeyFromItem(Map<String, dynamic> item) {
    return (item["logo"] ?? item["logoKey"] ?? "").toString().trim();
  }

  List<String> _photoKeysFromItem(Map<String, dynamic> item) {
    final raw = item["photoKeys"] ?? item["photo_keys"] ?? item["photos"];
    if (raw is List) {
      return raw
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _phoneFromItem(Map<String, dynamic> item) {
    return (item["telefono"] ?? item["phone"] ?? item["tel"] ?? "")
        .toString()
        .trim();
  }

  String _emailFromItem(Map<String, dynamic> item) {
    return (item["email"] ??
            item["mail"] ??
            item["Email"] ??
            item["e_mail"] ??
            item["emailAddress"] ??
            item["pec"] ??
            "")
        .toString()
        .trim();
  }

  List<_ActivityMapPoint> _applySearchFilter(List<_ActivityMapPoint> points) {
    final selectedType = _appliedActivityTypeQuery.trim().toLowerCase();
    final selectedCity = _appliedCityQuery.trim().toLowerCase();
    return points.where((p) {
      final typeOk =
          selectedType.isEmpty ||
          p.activityType.trim().toLowerCase().contains(selectedType);
      final cityOk =
          selectedCity.isEmpty ||
          p.city.trim().toLowerCase().contains(selectedCity);
      return typeOk && cityOk;
    }).toList();
  }

  LatLng? _extractLatLng(Map<String, dynamic> item) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(",", "."));
    }

    if (item["location"] is Map) {
      final loc = Map<String, dynamic>.from(item["location"] as Map);
      final lat = toDouble(loc["lat"] ?? loc["latitude"] ?? loc["latitudine"]);
      final lng = toDouble(
        loc["lng"] ?? loc["lon"] ?? loc["longitude"] ?? loc["longitudine"],
      );
      if (lat != null && lng != null) return LatLng(lat, lng);
    }

    final lat = toDouble(
      item["lat"] ??
          item["latitude"] ??
          item["latitudine"] ??
          item["geoLat"] ??
          item["geo_lat"],
    );
    final lng = toDouble(
      item["lng"] ??
          item["lon"] ??
          item["long"] ??
          item["longitude"] ??
          item["longitudine"] ??
          item["geoLng"] ??
          item["geo_lng"] ??
          item["geoLon"] ??
          item["geo_lon"],
    );
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  // ignore: unused_element
  Future<LatLng?> _geocodeAddress(String address) async {
    final cached = _geocodingCache[address];
    if (cached != null) return cached;
    try {
      final uri = Uri.https("nominatim.openstreetmap.org", "/search", {
        "format": "json",
        "limit": "1",
        "q": address,
      });
      final response = await http.get(
        uri,
        headers: {"User-Agent": "tipicooo-app/1.0"},
      );
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return null;
      final first = decoded.first;
      if (first is! Map) return null;

      final lat = double.tryParse((first["lat"] ?? "").toString());
      final lon = double.tryParse((first["lon"] ?? "").toString());
      if (lat == null || lon == null) return null;
      final point = LatLng(lat, lon);
      _geocodingCache[address] = point;
      return point;
    } catch (_) {
      return null;
    }
  }

  LatLng _fallbackLatLngFor(String seed) {
    final hash = seed.hashCode;
    final latOffset = ((hash % 300) - 150) / 1000.0;
    final lngOffset = (((hash ~/ 300) % 300) - 150) / 1000.0;
    return LatLng(41.9 + latOffset, 12.5 + lngOffset);
  }

  // ignore: unused_element
  Future<String?> _featuredImageUrl(_ActivityMapPoint point) {
    final candidate = point.logoKey.isNotEmpty
        ? point.logoKey
        : (point.photoKeys.isNotEmpty ? point.photoKeys.first : "");
    if (candidate.isEmpty || point.requestId.trim().isEmpty) {
      return Future.value(null);
    }
    final cacheKey = "${point.requestId}|$candidate";
    return _imageUrlCache.putIfAbsent(
      cacheKey,
      () => ActivityRequestService.fetchPhotoUrl(
        requestId: point.requestId,
        key: candidate,
      ),
    );
  }

  List<String> _visibleSheetMediaKeys(_ActivityMapPoint point) {
    final logo = point.logoKey.trim();
    final photos = point.photoKeys
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != logo)
        .toList();
    if (AuthState.isUserLoggedIn) {
      return <String>[if (logo.isNotEmpty) logo, ...photos];
    }
    return <String>[if (logo.isNotEmpty) logo, ...photos.take(3)];
  }

  // ignore: unused_element
  Future<List<String>> _sheetGalleryUrls(_ActivityMapPoint point) {
    final requestId = point.requestId.trim();
    if (requestId.isEmpty) return Future.value(const <String>[]);
    final keys = _visibleSheetMediaKeys(point);
    if (keys.isEmpty) return Future.value(const <String>[]);

    final cacheKey = "$requestId|${keys.join("|")}";
    return _galleryUrlCache.putIfAbsent(cacheKey, () async {
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
    });
  }

  LatLng _mapCenter(List<_ActivityMapPoint> points) {
    if (points.isEmpty) return const LatLng(41.9, 12.5);
    double latSum = 0;
    double lngSum = 0;
    for (final point in points) {
      latSum += point.latLng.latitude;
      lngSum += point.latLng.longitude;
    }
    return LatLng(latSum / points.length, lngSum / points.length);
  }

  Widget _buildActivityMapFrame(List<_ActivityMapPoint> points) {
    final center = _mapCenter(points);
    return Stack(
      children: [
        Positioned.fill(
          child: points.isEmpty
              ? const ColoredBox(
                  color: Color(0xFFE7F0E3),
                  child: Center(
                    child: Text(
                      "Nessuna attivita geolocalizzata.",
                      style: AppTextStyles.body,
                    ),
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: points.length > 1 ? 6.2 : 13.2,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                    onTap: (_, __) => _openFullScreenMap(),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tipicooo.app',
                      tileProvider: CancellableNetworkTileProvider(),
                    ),
                    MarkerLayer(
                      markers: points
                          .map(
                            (point) => Marker(
                              point: point.latLng,
                              width: 42,
                              height: 42,
                              child: GestureDetector(
                                onTap: () => _openActivityDetail(point),
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Color(0xFFC6342D),
                                  size: 36,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            child: IconButton(
              tooltip: "Aggiorna",
              onPressed: _refreshMapPoints,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    return FutureBuilder<List<_ActivityMapPoint>>(
      future: _mapPointsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _refreshMapPoints,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text("Riprova"),
                  SizedBox(width: 8),
                  Icon(Icons.refresh),
                ],
              ),
            ),
          );
        }
        final points = snapshot.data ?? const <_ActivityMapPoint>[];
        final filteredPoints = _applySearchFilter(points);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openFullScreenMap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text("Apri mappa"),
                    SizedBox(width: 8),
                    Icon(Icons.open_in_full, size: 18),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 560,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildActivityMapFrame(filteredPoints),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: false,
      headerTitle: 'Intorno a te',
      onRefresh: _refreshMapPoints,
      showBack: true,
      showHome: false,
      showBell: false,
      showProfile: true,
      onBackPressed: () {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      },
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: AppBodyLayout(
        children: [
          if (_activityTypeOptions.isNotEmpty) ...[
            DropdownMenu<String>(
              controller: _activityTypeController,
              requestFocusOnTap: true,
              enableFilter: true,
              enableSearch: true,
              expandedInsets: EdgeInsets.zero,
              label: const Text("Tipo di attività"),
              hintText: "Scrivi o seleziona",
              dropdownMenuEntries: _activityTypeOptions
                  .map((type) => DropdownMenuEntry<String>(value: type, label: type))
                  .toList(),
              onSelected: (value) {
                setState(() {
                  _activityTypeQuery = (value ?? "").trim();
                  _activityTypeController.text = _activityTypeQuery;
                  _cityQuery = '';
                  _cityController.clear();
                  _cityOptions = _computeCityOptionsForTypeQuery(
                    _activityTypeQuery,
                  );
                });
              },
            ),
            const SizedBox(height: 8),
          ],
          if (_activityTypeQuery.isNotEmpty && _cityOptions.isNotEmpty) ...[
            DropdownMenu<String>(
              controller: _cityController,
              requestFocusOnTap: true,
              enableFilter: true,
              enableSearch: true,
              expandedInsets: EdgeInsets.zero,
              label: const Text("Città"),
              hintText: "Scrivi o seleziona",
              dropdownMenuEntries: _cityOptions
                  .map((city) => DropdownMenuEntry<String>(value: city, label: city))
                  .toList(),
              onSelected: (value) {
                setState(() {
                  _cityQuery = (value ?? "").trim();
                  _cityController.text = _cityQuery;
                });
              },
            ),
            const SizedBox(height: 8),
          ],
          if (_activityTypeQuery.isNotEmpty || _cityQuery.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _appliedActivityTypeQuery = _activityTypeQuery.trim();
                    _appliedCityQuery = _cityQuery.trim();
                  });
                },
                icon: const Icon(Icons.search),
                label: const Text("Cerca"),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _activityTypeQuery = '';
                    _cityQuery = '';
                    _appliedActivityTypeQuery = '';
                    _appliedCityQuery = '';
                    _activityTypeController.clear();
                    _cityController.clear();
                    _cityOptions = const [];
                  });
                },
                child: const Text("Mostra tutte"),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildMapSection(),
        ],
      ),
    );
  }
}

class _ActivityMapPoint {
  const _ActivityMapPoint({
    required this.id,
    required this.requestId,
    required this.title,
    required this.address,
    required this.activityType,
    required this.city,
    required this.description,
    required this.logoKey,
    required this.photoKeys,
    required this.phone,
    required this.email,
    required this.reviewSummary,
    required this.latLng,
    required this.approximate,
  });

  final String id;
  final String requestId;
  final String title;
  final String address;
  final String activityType;
  final String city;
  final String description;
  final String logoKey;
  final List<String> photoKeys;
  final String phone;
  final String email;
  final Map<String, dynamic>? reviewSummary;
  final LatLng latLng;
  final bool approximate;
}

class _FullScreenMapPage extends StatefulWidget {
  const _FullScreenMapPage({
    required this.loadPoints,
    required this.selectForPayment,
  });

  final Future<List<_ActivityMapPoint>> Function() loadPoints;
  final bool selectForPayment;

  @override
  State<_FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<_FullScreenMapPage> {
  late Future<List<_ActivityMapPoint>> _pointsFuture;
  final Map<String, Future<String?>> _imageUrlCache = {};
  final Map<String, Future<List<String>>> _galleryUrlCache = {};

  @override
  void initState() {
    super.initState();
    _pointsFuture = widget.loadPoints();
  }

  Future<void> _refresh() async {
    setState(() {
      _pointsFuture = widget.loadPoints();
    });
  }

  Future<String?> _featuredImageUrl(_ActivityMapPoint point) {
    final candidate = point.logoKey.isNotEmpty
        ? point.logoKey
        : (point.photoKeys.isNotEmpty ? point.photoKeys.first : "");
    if (candidate.isEmpty || point.requestId.trim().isNotEmpty == false) {
      return Future.value(null);
    }
    final cacheKey = "${point.requestId}|$candidate";
    return _imageUrlCache.putIfAbsent(
      cacheKey,
      () => ActivityRequestService.fetchPhotoUrl(
        requestId: point.requestId,
        key: candidate,
      ),
    );
  }

  List<String> _visibleSheetMediaKeys(_ActivityMapPoint point) {
    final logo = point.logoKey.trim();
    final photos = point.photoKeys
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != logo)
        .toList();
    if (AuthState.isUserLoggedIn) {
      return <String>[if (logo.isNotEmpty) logo, ...photos];
    }
    return <String>[if (logo.isNotEmpty) logo, ...photos.take(3)];
  }

  Future<List<String>> _sheetGalleryUrls(_ActivityMapPoint point) {
    final requestId = point.requestId.trim();
    if (requestId.isEmpty) return Future.value(const <String>[]);
    final keys = _visibleSheetMediaKeys(point);
    if (keys.isEmpty) return Future.value(const <String>[]);

    final cacheKey = "$requestId|${keys.join("|")}";
    return _galleryUrlCache.putIfAbsent(cacheKey, () async {
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
    });
  }

  void _openActivityDetail(_ActivityMapPoint point) {
    if (widget.selectForPayment) {
      Navigator.pushNamed(
        context,
        AppRoutes.createPurchase,
        arguments: {
          "activityRequestId": point.requestId,
          "activityTitle": point.title,
        },
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          title: point.title,
          address: point.address,
          typeLabel: point.activityType,
          description: point.description,
          approximate: point.approximate,
          requestId: point.requestId,
          logoKey: point.logoKey,
          photoKeys: point.photoKeys,
          phone: point.phone,
          email: point.email,
          reviewSummary: point.reviewSummary,
        ),
      ),
    );
  }

  LatLng _mapCenter(List<_ActivityMapPoint> points) {
    if (points.isEmpty) return const LatLng(41.9, 12.5);
    double latSum = 0;
    double lngSum = 0;
    for (final point in points) {
      latSum += point.latLng.latitude;
      lngSum += point.latLng.longitude;
    }
    return LatLng(latSum / points.length, lngSum / points.length);
  }

  // ignore: unused_element
  void _showActivitySheet(_ActivityMapPoint point) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _buildActivitySheet(point),
    );
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

  Future<void> _callPhoneValue(BuildContext context, String value) async {
    final normalized = _normalizePhone(value);
    if (normalized.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: normalized);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossibile avviare la chiamata.")),
      );
    }
  }

  Future<void> _sendEmailValue(BuildContext context, String value) async {
    final email = value.trim();
    if (email.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: email);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossibile aprire l'email.")),
      );
    }
  }

  Widget _buildActivitySheet(_ActivityMapPoint point) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAD9B6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD9C08A)),
                ),
                child: FutureBuilder<String?>(
                  future: _featuredImageUrl(point),
                  builder: (context, snapshot) {
                    final imageUrl = snapshot.data ?? "";
                    if (imageUrl.isEmpty) {
                      return const Icon(
                        Icons.store,
                        color: Color(0xFF8A6A3D),
                        size: 30,
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.store,
                          color: Color(0xFF8A6A3D),
                          size: 30,
                        ),
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
                    if (point.activityType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1E2C3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          point.activityType,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 12,
                            color: const Color(0xFF7A5B2F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      point.title,
                      style: AppTextStyles.pageMessage.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (point.address.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.place,
                            size: 16,
                            color: Color(0xFF8A6A3D),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              point.address,
                              style: AppTextStyles.body,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (point.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        point.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(height: 1.35),
                      ),
                    ],
                    if (point.reviewSummary != null) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (_) {
                          final s = ActivityReviewSummary.fromAny(
                            point.reviewSummary!,
                          );
                          if (!s.hasData) return const SizedBox.shrink();
                          final chunks = <String>[];
                          if (s.recommendedCount > 0) {
                            chunks.add(
                              "Consigliato da ${s.recommendedCount} utenti",
                            );
                          }
                          if (s.avgOverall != null) {
                            chunks.add(
                              "Media ${s.avgOverall!.toStringAsFixed(1).replaceAll('.', ',')}/10",
                            );
                          }
                          if (chunks.isEmpty) return const SizedBox.shrink();
                          return Text(
                            chunks.join(" • "),
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ],
                    if (point.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 16,
                            color: Color(0xFF8A6A3D),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _callPhoneValue(context, point.phone),
                            child: Text(
                              point.phone.trim(),
                              style: AppTextStyles.body.copyWith(
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (point.email.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            size: 16,
                            color: Color(0xFF8A6A3D),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  _sendEmailValue(context, point.email),
                              child: Text(
                                point.email.trim(),
                                style: AppTextStyles.body.copyWith(
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (point.approximate) ...[
                      const SizedBox(height: 6),
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
          FutureBuilder<List<String>>(
            future: _sheetGalleryUrls(point),
            builder: (context, snapshot) {
              final urls = snapshot.data ?? const <String>[];
              if (urls.length <= 1) return const SizedBox.shrink();
              final thumbs = urls.skip(1).take(3).toList();
              if (thumbs.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 62,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: thumbs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final imageUrl = thumbs[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrl,
                          width: 62,
                          height: 62,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 62,
                            height: 62,
                            color: const Color(0xFFEAD9B6),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.photo,
                              color: Color(0xFF8A6A3D),
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
        ],
      ),
    );
  }

  Widget _buildMap(List<_ActivityMapPoint> points) {
    final center = _mapCenter(points);
    return Stack(
      children: [
        Positioned.fill(
          child: points.isEmpty
              ? const ColoredBox(
                  color: Color(0xFFE7F0E3),
                  child: Center(
                    child: Text(
                      "Nessuna attivita geolocalizzata.",
                      style: AppTextStyles.body,
                    ),
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: points.length > 1 ? 6.2 : 13.2,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tipicooo.app',
                      tileProvider: CancellableNetworkTileProvider(),
                    ),
                    MarkerLayer(
                      markers: points
                          .map(
                            (point) => Marker(
                              point: point.latLng,
                              width: 42,
                              height: 42,
                              child: GestureDetector(
                                onTap: () {
                                  _openActivityDetail(point);
                                },
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Color(0xFFC6342D),
                                  size: 36,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            child: IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mappa attivita")),
      body: FutureBuilder<List<_ActivityMapPoint>>(
        future: _pointsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _refresh,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text("Riprova"),
                    SizedBox(width: 8),
                    Icon(Icons.refresh),
                  ],
                ),
              ),
            );
          }
          return _buildMap(snapshot.data ?? const []);
        },
      ),
    );
  }
}
