import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/pages/activity_detail_page.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/utils/activity_review_summary.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

class DriversPage extends StatefulWidget {
  const DriversPage({super.key});

  @override
  State<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage> {
  static const List<double> _radiusOptionsKm = <double>[10, 20, 50];
  late Future<List<Map<String, dynamic>>> _futureItems;
  final TextEditingController _countrySearchController =
      TextEditingController();
  String _countryQuery = "";
  double? _userLat;
  double? _userLng;
  double _selectedRadiusKm = 20.0;
  bool _locating = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _resolveUserPosition();
    _futureItems = _loadItems();
  }

  @override
  void dispose() {
    _countrySearchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await _resolveUserPosition();
    setState(() {
      _futureItems = _loadItems();
    });
    await _futureItems;
  }

  Future<void> _resolveUserPosition() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _userLat = null;
          _userLng = null;
          _locationError = "Attiva la posizione per vedere le attività entro 20 km.";
          _locating = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _userLat = null;
          _userLng = null;
          _locationError = "Permesso posizione negato. Consenti il GPS per il filtro 20 km.";
          _locating = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _locationError = null;
        _locating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userLat = null;
        _userLng = null;
        _locationError = "Impossibile leggere la posizione al momento.";
        _locating = false;
      });
    }
  }

  bool _asBool(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final raw = item[key];
      if (raw is bool) return raw;
      final value = (raw ?? "").toString().trim().toLowerCase();
      if (value == "true" || value == "1" || value == "si" || value == "sì") {
        return true;
      }
      if (value == "false" || value == "0" || value == "no") {
        return false;
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> _loadItems() async {
    final items = await ActivityRequestService.fetchApprovedActivitiesPublic();
    final filtered = items.where((it) {
      return _hasAnyDriverFeature(it);
    }).toList();

    filtered.sort((a, b) {
      final ad = (a["createdAt"] ?? "").toString();
      final bd = (b["createdAt"] ?? "").toString();
      return bd.compareTo(ad);
    });
    return filtered;
  }

  bool _hasAnyDriverFeature(Map<String, dynamic> item) {
    final hasPrivateParking = _asBool(item, const [
      "has_private_parking",
      "hasPrivateParking",
    ]);
    final hasBusinessLunch = _asBool(item, const [
      "has_business_lunch",
      "hasBusinessLunch",
    ]);
    final hasShowers = _asBool(item, const [
      "has_showers",
      "hasShowers",
    ]);
    final truckAllowed = _asBool(item, const [
      "truck_parking_allowed",
      "truckParkingAllowed",
    ]);
    final guestOptions = _guestParkingOptions(item);
    return hasPrivateParking ||
        hasBusinessLunch ||
        hasShowers ||
        truckAllowed ||
        guestOptions.isNotEmpty;
  }

  String _title(Map<String, dynamic> item) {
    final insegna = (item["insegna"] ?? "").toString().trim();
    final ragione = (item["ragione_sociale"] ?? "").toString().trim();
    if (insegna.isNotEmpty) return insegna;
    if (ragione.isNotEmpty) return ragione;
    return (item["requestId"] ?? item["id"] ?? "Attività").toString();
  }

  String _cityLine(Map<String, dynamic> item) {
    final citta = (item["citta"] ?? "").toString().trim();
    final provincia = (item["provincia"] ?? "").toString().trim();
    final paese = (item["paese"] ?? "").toString().trim();
    return [
      if (citta.isNotEmpty) citta,
      if (provincia.isNotEmpty) provincia,
      if (paese.isNotEmpty) paese,
    ].join(", ");
  }

  String _country(Map<String, dynamic> item) {
    return (item["paese"] ?? item["country"] ?? "").toString().trim();
  }

  String _type(Map<String, dynamic> item) {
    return (item["tipo_attivita"] ?? item["activityType"] ?? "")
        .toString()
        .trim();
  }

  double? _asDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(raw.trim().replaceAll(",", "."));
    }
    return null;
  }

  double? _itemLat(Map<String, dynamic> item) {
    final direct = _asDouble(item["lat"] ?? item["latitude"]);
    if (direct != null) return direct;
    final loc = item["location"];
    if (loc is Map) {
      return _asDouble(loc["lat"] ?? loc["latitude"]);
    }
    return null;
  }

  double? _itemLng(Map<String, dynamic> item) {
    final direct = _asDouble(item["lng"] ?? item["lon"] ?? item["longitude"]);
    if (direct != null) return direct;
    final loc = item["location"];
    if (loc is Map) {
      return _asDouble(loc["lng"] ?? loc["lon"] ?? loc["longitude"]);
    }
    return null;
  }

  double? _distanceKmFromUser(Map<String, dynamic> item) {
    if (_userLat == null || _userLng == null) return null;
    final lat = _itemLat(item);
    final lng = _itemLng(item);
    if (lat == null || lng == null) return null;
    final meters = Geolocator.distanceBetween(_userLat!, _userLng!, lat, lng);
    return meters / 1000.0;
  }

  int _starsValue(Map<String, dynamic> item) {
    final raw = item["numero_stelle"] ?? item["numeroStelle"] ?? item["stars"];
    if (raw is num) {
      final n = raw.toInt();
      if (n >= 1 && n <= 5) return n;
      return 0;
    }
    final parsed = int.tryParse((raw ?? "").toString().trim()) ?? 0;
    if (parsed < 1 || parsed > 5) return 0;
    return parsed;
  }

  Widget _starsRow(int stars) {
    if (stars <= 0) return const SizedBox.shrink();
    return Row(
      children: List.generate(
        stars,
        (_) => const Padding(
          padding: EdgeInsets.only(right: 2),
          child: Icon(
            Icons.star,
            size: 16,
            color: Color(0xFFE0B04F),
          ),
        ),
      ),
    );
  }

  List<String> _guestParkingOptions(Map<String, dynamic> item) {
    final raw = item["guest_parking_options"] ?? item["guestParkingOptions"];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  bool _hasParkingService(Map<String, dynamic> item) {
    final hasPrivateParking = _asBool(item, const [
      "has_private_parking",
      "hasPrivateParking",
    ]);
    final truckAllowed = _asBool(item, const [
      "truck_parking_allowed",
      "truckParkingAllowed",
    ]);
    final guestOptions = _guestParkingOptions(item);
    return hasPrivateParking || truckAllowed || guestOptions.isNotEmpty;
  }

  bool _hasBusinessLunchService(Map<String, dynamic> item) {
    return _asBool(item, const ["has_business_lunch", "hasBusinessLunch"]);
  }

  bool _hasShowersService(Map<String, dynamic> item) {
    return _asBool(item, const ["has_showers", "hasShowers"]);
  }

  bool _hasBedService(Map<String, dynamic> item) {
    final type = _type(item).toLowerCase();
    if (type.isEmpty) return false;
    const bedKeywords = <String>[
      "hotel",
      "albergo",
      "b&b",
      "bed and breakfast",
      "ostello",
      "affittacamere",
      "agriturismo",
      "residence",
      "motel",
      "locanda",
    ];
    return bedKeywords.any(type.contains);
  }

  Widget _serviceBadge({
    required Widget icon,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F2E3),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE0D2AA)),
        ),
        child: SizedBox(
          width: 18,
          height: 18,
          child: Center(
            child: IconTheme(
              data: const IconThemeData(
                size: 18,
                color: Color(0xFF4A4A4A),
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  height: 1,
                  color: Color(0xFF4A4A4A),
                ),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> item) {
    final requestId =
        (item["requestId"] ?? item["id"] ?? "").toString().trim();
    final reviewSummary = ActivityReviewSummary.fromAny(item).toMapOrNull();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          title: _title(item),
          address: _buildAddress(item),
          typeLabel: _type(item),
          description:
              (item["descrizione"] ?? item["description"] ?? "").toString(),
          approximate: false,
          requestId: requestId,
          logoKey: (item["logo"] ?? "").toString(),
          photoKeys: _photoKeys(item),
          phone: (item["telefono"] ?? "").toString(),
          email: (item["email"] ?? "").toString(),
          reviewSummary: reviewSummary,
        ),
      ),
    );
  }

  String _buildAddress(Map<String, dynamic> item) {
    final via = (item["via"] ?? "").toString().trim();
    final numero = (item["numero_civico"] ?? "").toString().trim();
    final cap = (item["cap"] ?? "").toString().trim();
    final city = (item["citta"] ?? "").toString().trim();
    final province = (item["provincia"] ?? "").toString().trim();
    return [
      if (via.isNotEmpty) "$via ${numero.isNotEmpty ? numero : ""}".trim(),
      if (cap.isNotEmpty || city.isNotEmpty || province.isNotEmpty)
        [cap, city, province].where((e) => e.isNotEmpty).join(" "),
    ].where((e) => e.isNotEmpty).join(", ");
  }

  List<String> _photoKeys(Map<String, dynamic> item) {
    final raw = item["photoKeys"] ?? item["photo_keys"] ?? item["photos"];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: false,
      headerTitle: "Attività per autisti",
      onRefresh: _refresh,
      showBack: true,
      showHome: true,
      showProfile: true,
      showBell: true,
      showLogout: false,
      body: AppBodyLayout(
        children: [
          const Text(
            "Attività per autisti",
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Elenco attività con caratteristiche utili agli autisti.",
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (_locating)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                "Ricerca posizione in corso...",
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            )
          else if (_locationError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _locationError!,
                style: AppTextStyles.body.copyWith(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
            )
          else
            Text(
              "Mostro attività nel raggio di ${_selectedRadiusKm.toInt()} km.",
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _radiusOptionsKm.map((radius) {
              final selected = _selectedRadiusKm == radius;
              return ChoiceChip(
                label: Text("${radius.toInt()} km"),
                selected: selected,
                onSelected: (_) {
                  if (_selectedRadiusKm == radius) return;
                  setState(() {
                    _selectedRadiusKm = radius;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: TextField(
              controller: _countrySearchController,
              onChanged: (value) {
                setState(() {
                  _countryQuery = value.trim().toLowerCase();
                });
              },
              decoration: const InputDecoration(
                hintText: "Cerca per Paese",
                border: InputBorder.none,
                icon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _futureItems,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data ?? const <Map<String, dynamic>>[];

              final byRadius = (_userLat == null || _userLng == null)
                  ? <Map<String, dynamic>>[]
                  : items.where((it) {
                      final km = _distanceKmFromUser(it);
                      return km != null && km <= _selectedRadiusKm;
                    }).toList();

              final filteredByCountry = _countryQuery.isEmpty
                  ? byRadius
                  : byRadius.where((it) {
                      final country = _country(it).toLowerCase();
                      return country.contains(_countryQuery);
                    }).toList();

              if (_userLat == null || _userLng == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "Posizione non disponibile. Attiva il GPS per mostrare le attività entro 20 km.",
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (filteredByCountry.isEmpty) {
                final hasFarActivities = items.isNotEmpty;
                final msg = hasFarActivities
                    ? "Nessuna attività trovata entro ${_selectedRadiusKm.toInt()} km con i filtri selezionati. Ci sono attività affiliate, ma più distanti."
                    : "Nessuna attività trovata con i filtri selezionati.";
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    msg,
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Column(
                children: filteredByCountry.map((it) {
                  final type = _type(it);
                  final stars = _starsValue(it);
                  final city = _cityLine(it);
                  final country = _country(it);
                  final hasParking = _hasParkingService(it);
                  final hasLunch = _hasBusinessLunchService(it);
                  final hasShowers = _hasShowersService(it);
                  final hasBed = _hasBedService(it);
                  final km = _distanceKmFromUser(it);
                  final reviewSummary = ActivityReviewSummary.fromAny(it);
                  final kmText = km == null
                      ? ""
                      : "${km.toStringAsFixed(1).replaceAll('.', ',')} km";
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (type.isNotEmpty)
                            Text(
                              type,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          Text(
                            _title(it),
                            style: AppTextStyles.pageMessage,
                          ),
                          if (stars > 0) ...[
                            const SizedBox(height: 4),
                            _starsRow(stars),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (city.isNotEmpty) Text("Località: $city"),
                            if (country.isNotEmpty) Text("Paese: $country"),
                            if (kmText.isNotEmpty) Text("Distanza: $kmText"),
                            if (reviewSummary.recommendedCount > 0)
                              Text(
                                "Consigliato da ${reviewSummary.recommendedCount} utenti",
                              ),
                            if (reviewSummary.avgOverall != null)
                              Text(
                                "Valutazione media: ${reviewSummary.avgOverall!.toStringAsFixed(1).replaceAll('.', ',')}/10",
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (hasParking)
                                  _serviceBadge(
                                    icon: const Text(
                                      "P",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    tooltip: "Parcheggio disponibile",
                                  ),
                                if (hasLunch)
                                  _serviceBadge(
                                    icon: const Icon(
                                      Icons.restaurant,
                                      size: 18,
                                    ),
                                    tooltip: "Pranzi/Cene di lavoro",
                                  ),
                                if (hasShowers)
                                  _serviceBadge(
                                    icon: const Icon(
                                      Icons.shower,
                                      size: 18,
                                    ),
                                    tooltip: "Docce disponibili",
                                  ),
                                if (hasBed)
                                  _serviceBadge(
                                    icon: const Icon(
                                      Icons.bed,
                                      size: 18,
                                    ),
                                    tooltip: "Pernottamento disponibile",
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openDetail(it),
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

