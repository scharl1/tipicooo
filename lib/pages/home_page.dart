import 'dart:async';
import 'dart:convert';
// ignore_for_file: unused_element
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show Distance, LatLng, LengthUnit;
import 'package:tipicooo/activity/activities_service.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/pages/activity_detail_page.dart';
import 'package:tipicooo/utils/activity_review_summary.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/base_page.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/layout/app_body_layout.dart';
import '../theme/app_text_styles.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late Future<List<_ActivityMapPoint>> _mapPointsFuture;
  final Map<String, LatLng> _geocodingCache = {};
  AnimationController? _swingController;
  Timer? _welcomeTimer;
  bool _showWelcomeBanner = true;
  final Map<String, Future<String?>> _imageUrlCache = {};
  final Map<String, Future<List<String>>> _galleryUrlCache = {};
  final Distance _distance = const Distance();
  LatLng? _userLatLng;

  Future<bool>? _hasApprovedActivityFuture;
  late final VoidCallback _authListener;

  AnimationController get _safeSwingController {
    _swingController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..repeat(reverse: true);
    return _swingController!;
  }

  @override
  void initState() {
    super.initState();
    _mapPointsFuture = _loadMapPoints();
    _safeSwingController;
    _welcomeTimer = Timer(const Duration(seconds: 10), _dismissWelcomeBanner);

    _authListener = () {
      final loggedIn = AuthState.isLoggedIn.value == true;
      if (!mounted) return;
      if (!loggedIn) {
        if (_hasApprovedActivityFuture != null) {
          setState(() {
            _hasApprovedActivityFuture = null;
          });
        }
        return;
      }
      if (_hasApprovedActivityFuture == null) {
        setState(() {
          _hasApprovedActivityFuture = _canAcceptPayments();
        });
      }
    };
    AuthState.isLoggedIn.addListener(_authListener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _authListener());
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    _swingController?.dispose();
    AuthState.isLoggedIn.removeListener(_authListener);
    super.dispose();
  }

  Future<bool> _canAcceptPayments() async {
    try {
      final activities = await ActivityRequestService.fetchActivitiesForMe();
      const allowedRoles = <String>{'owner', 'staff', 'employee', 'cashier'};
      return activities.any((it) {
        final status =
            (it["status"] ?? "").toString().trim().toLowerCase();
        if (status != "approved") return false;
        final roleType =
            (it["roleType"] ?? "").toString().trim().toLowerCase();
        if (roleType.isEmpty) return false;
        return allowedRoles.contains(roleType);
      });
    } catch (_) {
      return false;
    }
  }

  void _dismissWelcomeBanner() {
    if (!mounted || !_showWelcomeBanner) return;
    setState(() {
      _showWelcomeBanner = false;
    });
  }


  Future<LatLng?> _resolveUserPosition() async {
    if (kIsWeb) return null;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 8));

      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshMapPoints() async {
    setState(() {
      _mapPointsFuture = _loadMapPoints();
    });
  }

  void _openFullScreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenMapPage(loadPoints: _loadMapPoints),
      ),
    );
  }

  Future<List<_ActivityMapPoint>> _loadMapPoints() async {
    List<Map<String, dynamic>> sourceItems = <Map<String, dynamic>>[];
    final userLatLng = await _resolveUserPosition();
    _userLatLng = userLatLng;

    // 1) Sorgente pubblica: attività confermate visibili anche da anonimo.
    sourceItems = await ActivityRequestService.fetchApprovedActivitiesPublic();
    sourceItems = sourceItems.where(_isConfirmedItem).toList();
    sourceItems = _dedupeItems(sourceItems);

    // 2) Fallback pubblico legacy.
    if (sourceItems.isEmpty && !kIsWeb) {
      final publicRaw = await ActivitiesService.instance.getActivities();
      sourceItems = _normalizeItems(publicRaw);
      sourceItems = sourceItems.where(_isConfirmedItem).toList();
      sourceItems = _dedupeItems(sourceItems);
    }

    // 3) Fallback autenticato su approved.
    if (sourceItems.isEmpty && AuthState.isUserLoggedIn) {
      sourceItems = await ActivityRequestService.fetchApprovedActivities();
      sourceItems = sourceItems.where(_isConfirmedItem).toList();
      sourceItems = _dedupeItems(sourceItems);
    }

    final points = <_ActivityMapPoint>[];

    for (var item in sourceItems) {
      final requestId = (item["requestId"] ?? item["id"] ?? "").toString();
      final baseDescription = _descriptionFromItem(item);

      // Alcuni endpoint ritornano item "light"; se manca l'indirizzo, completiamo col detail.
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
      final typeLabel = _typeFromItem(item);
      final city = _cityFromItem(item);
      final province = _provinceFromItem(item);
      var description = _descriptionFromItem(item);
      if (description.isEmpty) description = baseDescription;
      final logoKey = _logoKeyFromItem(item);
      final photoKeys = _photoKeysFromItem(item);
      final phone = _phoneFromItem(item);
      final email = _emailFromItem(item);
      final reviewSummary = ActivityReviewSummary.fromAny(item).toMapOrNull();
      final id = (item["id"] ?? item["requestId"] ?? title).toString();

      final direct = _extractLatLng(item);
      LatLng? point = direct;

      if (point == null && address.isNotEmpty) {
        point = await _geocodeAddress(address);
      }

      if (point == null && address.isNotEmpty) {
        point = _fallbackLatLngFor(id);
      }

      if (point != null) {
        final distanceKm = userLatLng == null
            ? null
            : _distance.as(LengthUnit.Kilometer, userLatLng, point);
        points.add(
          _ActivityMapPoint(
            id: id,
            requestId: requestId,
            title: title,
            address: address,
            typeLabel: typeLabel,
            city: city,
            province: province,
            description: description,
            logoKey: logoKey,
            photoKeys: photoKeys,
            phone: phone,
            email: email,
            reviewSummary: reviewSummary,
            latLng: point,
            distanceKm: distanceKm,
            approximate: direct == null,
          ),
        );
      }
    }

    if (userLatLng != null) {
      points.sort((a, b) {
        final ad = a.distanceKm ?? double.infinity;
        final bd = b.distanceKm ?? double.infinity;
        return ad.compareTo(bd);
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

  List<Map<String, dynamic>> _dedupeItems(List<Map<String, dynamic>> items) {
    final byKey = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final key = (item["requestId"] ?? item["id"] ?? "").toString().trim();
      if (key.isEmpty) continue;
      byKey[key] = item;
    }
    return byKey.values.toList();
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

  String _typeFromItem(Map<String, dynamic> item) {
    final tipo =
        (item["tipo_attivita"] ??
                item["categoria"] ??
                item["category"] ??
                item["type"] ??
                "")
            .toString()
            .trim();
    return tipo;
  }

  String _cityFromItem(Map<String, dynamic> item) {
    return (item["citta"] ?? item["cittaComune"] ?? item["city"] ?? "")
        .toString()
        .trim();
  }

  String _provinceFromItem(Map<String, dynamic> item) {
    return (item["provincia"] ?? item["province"] ?? "").toString().trim();
  }

  String _descriptionFromItem(Map<String, dynamic> item) {
    final desc = (item["descrizione"] ?? item["description"] ?? "")
        .toString()
        .trim();
    return desc;
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

  LatLng? _extractLatLng(Map<String, dynamic> item) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final parsed = double.tryParse(v.toString().replaceAll(",", "."));
      return parsed;
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

  LatLng _mapCenter(List<_ActivityMapPoint> points) {
    if (_userLatLng != null) return _userLatLng!;
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 40,
                          color: Color(0xFF4E6A4A),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Mappa vuota: si popolera\ncon le attivita registrate.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body,
                        ),
                      ],
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
                              child: Tooltip(
                                message: point.address.isEmpty
                                    ? point.title
                                    : point.approximate
                                    ? '${point.title}\n${point.address}\nPosizione indicativa'
                                    : '${point.title}\n${point.address}',
                                child: GestureDetector(
                                  onTap: () {
                                    _showActivitySheet(point);
                                  },
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Color(0xFFC6342D),
                                    size: 36,
                                  ),
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
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  points.isEmpty
                      ? "Nessuna attivita geolocalizzata."
                      : "Attivita in mappa",
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                child: IconButton(
                  tooltip: "Aggiorna",
                  onPressed: _refreshMapPoints,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showActivitySheet(_ActivityMapPoint point) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _buildActivitySheet(point);
      },
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
                    if (point.typeLabel.isNotEmpty)
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
                          point.typeLabel,
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

  Widget _buildMapSection() {
    return FutureBuilder<List<_ActivityMapPoint>>(
      future: _mapPointsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6EF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8A6A3D), width: 2),
            ),
            child: const Center(
              child: SizedBox(
                height: 26,
                width: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6EF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8A6A3D), width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Errore caricamento mappa attivita.",
                    style: AppTextStyles.body,
                  ),
                ),
                TextButton(
                  onPressed: _refreshMapPoints,
                  child: const Text("Riprova"),
                ),
              ],
            ),
          );
        }

        final points = snapshot.data ?? const <_ActivityMapPoint>[];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6EF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF8A6A3D), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Mappa delle attivita",
                style: AppTextStyles.pageMessage.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _openFullScreenMap,
                child: SizedBox(
                  height: 300,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: IgnorePointer(child: _buildActivityMapFrame(points)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Tocca la mappa per aprirla a schermo intero.",
                style: AppTextStyles.body.copyWith(fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openActivityDetail(_ActivityMapPoint point) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          title: point.title,
          address: point.address,
          typeLabel: point.typeLabel,
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

  Widget _buildActivitiesListSection() {
    return FutureBuilder<List<_ActivityMapPoint>>(
      future: _mapPointsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6EF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8A6A3D), width: 2),
            ),
            child: const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          );
        }

        final points = snapshot.data ?? const <_ActivityMapPoint>[];
        if (points.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Attività registrate",
              style: AppTextStyles.pageMessage.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 10),
            for (final point in points) ...[
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openActivityDetail(point),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6EF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8A6A3D),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 170,
                          child: FutureBuilder<String?>(
                            future: _featuredImageUrl(point),
                            builder: (context, imageSnapshot) {
                              final imageUrl = imageSnapshot.data ?? "";
                              if (imageUrl.isEmpty) {
                                return Container(
                                  color: const Color(0xFFEAD9B6),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.store,
                                    size: 42,
                                    color: Color(0xFF8A6A3D),
                                  ),
                                );
                              }
                              return Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFEAD9B6),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.store,
                                    size: 42,
                                    color: Color(0xFF8A6A3D),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (point.typeLabel.isNotEmpty)
                        Text(
                          point.typeLabel,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7A5B2F),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        point.title,
                        style: AppTextStyles.pageMessage.copyWith(fontSize: 18),
                      ),
                      if (point.city.isNotEmpty ||
                          point.province.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            point.city,
                            point.province,
                          ].where((e) => e.trim().isNotEmpty).join(" - "),
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildThanksSign() {
    return AnimatedBuilder(
      animation: _safeSwingController,
      builder: (context, child) {
        final t = _safeSwingController.value;
        final angle = (t - 0.5) * 0.08;
        return Transform.rotate(
          angle: angle,
          alignment: Alignment.topCenter,
          child: child,
        );
      },
      child: Center(
        child: SizedBox(
          width: 360,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Cordicelle inclinate che convergono verso il chiodino centrale.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: const Size(360, 34),
                    painter: _HangingRopesPainter(),
                  ),
                ),
              ),
              // Chiodino centrato rispetto al cartello.
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: const Offset(0, -4),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB71C1C),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFCDD2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 24),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE7C26A)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Text(
                  "Grazie per utilizzare Tipic.ooo: ogni suggerimento è un passo verso la valorizzazione del nostro territorio!",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSign() {
    if (!_showWelcomeBanner) return const SizedBox.shrink();
    return Center(
      child: GestureDetector(
        onTap: _dismissWelcomeBanner,
        child: Container(
          width: 360,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE8A8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0B04F)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  "Benvenuto in Tipic.ooo! Siamo in continua evoluzione.\nSe trovi bug, segnalaceli. Grazie!",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.pageMessage,
                ),
              ),
            ],
          ),
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
        return BasePage(
          scrollable: false,
          headerTitle: "Tipic.ooo",
          onRefresh: _refreshMapPoints,

          showBell: true,
          showProfile: isLoggedIn,
          showHome: false,
          showBack: false,
          showLogout: false,

          // ⭐ Home NON deve avere un indice della bottom bar
          bottomNavigationBar: const AppBottomNav(currentIndex: -1),

          body: AppBodyLayout(
            children: [
              _buildWelcomeSign(),
              if (isLoggedIn) ...[
                BlueNarrowButton(
                  label: "Registra un tuo pagamento",
                  icon: Icons.receipt_long,
                  color: Colors.green,
                  borderColor: AppColors.yellow,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.search,
                      arguments: {"selectForPayment": true},
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (_hasApprovedActivityFuture != null)
                  FutureBuilder<bool>(
                    future: _hasApprovedActivityFuture,
                    builder: (context, snapshot) {
                      final ok = snapshot.data == true;
                      if (!ok) return const SizedBox.shrink();
                      return Column(
                        children: [
                          BlueNarrowButton(
                            label: "Conferma pagamenti",
                            icon: Icons.point_of_sale,
                            color: Colors.green,
                            borderColor: AppColors.yellow,
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.activityPayments,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
              ],
              BlueNarrowButton(
                label: "Sei un autista",
                icon: Icons.local_shipping_outlined,
                color: Colors.green,
                borderColor: AppColors.yellow,
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.drivers);
                },
              ),
              const SizedBox(height: 12),
              _buildThanksSign(),
              _buildMapSection(),
              _buildActivitiesListSection(),
            ],
          ),
        );
      },
    );
  }
}

class _HangingRopesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ropePaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Coordinate relative al layout originale da 360px, ma adattive alla width reale.
    final w = size.width;
    final centerX = w / 2.0;
    const baseW = 360.0;

    double sx(double x) => x * (w / baseW);

    final leftPath = Path()
      ..moveTo(sx(118), 28)
      ..quadraticBezierTo(sx(146), 16, centerX, 8);

    final rightPath = Path()
      ..moveTo(sx(242), 28)
      ..quadraticBezierTo(sx(214), 16, centerX, 8);

    canvas.drawPath(leftPath, ropePaint);
    canvas.drawPath(rightPath, ropePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ActivityMapPoint {
  const _ActivityMapPoint({
    required this.id,
    required this.requestId,
    required this.title,
    required this.address,
    required this.typeLabel,
    required this.city,
    required this.province,
    required this.description,
    required this.logoKey,
    required this.photoKeys,
    required this.phone,
    required this.email,
    required this.reviewSummary,
    required this.latLng,
    required this.distanceKm,
    required this.approximate,
  });

  final String id;
  final String requestId;
  final String title;
  final String address;
  final String typeLabel;
  final String city;
  final String province;
  final String description;
  final String logoKey;
  final List<String> photoKeys;
  final String phone;
  final String email;
  final Map<String, dynamic>? reviewSummary;
  final LatLng latLng;
  final double? distanceKm;
  final bool approximate;
}

class _FullScreenMapPage extends StatefulWidget {
  const _FullScreenMapPage({required this.loadPoints});

  final Future<List<_ActivityMapPoint>> Function() loadPoints;

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          title: point.title,
          address: point.address,
          typeLabel: point.typeLabel,
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

  void _showActivitySheet(_ActivityMapPoint point) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _buildActivitySheet(point);
      },
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
                    if (point.typeLabel.isNotEmpty)
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
                          point.typeLabel,
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

  LatLng _mapCenter(List<_ActivityMapPoint> points) {
    if (points.isEmpty) return const LatLng(41.9, 12.5);
    return points.first.latLng;
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
