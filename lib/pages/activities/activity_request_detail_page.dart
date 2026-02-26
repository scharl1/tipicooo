import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ActivityRequestDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const ActivityRequestDetailPage({
    super.key,
    required this.data,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    String field(String key) => (data[key] ?? "").toString();
    final LatLng? mapPoint = _extractPoint();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dettaglio attività"),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            _sectionTitle("Dati principali"),
            _row("Insegna", field("insegna")),
            _row("Ragione sociale", field("ragione_sociale")),
            _row("Tipo attività", field("tipo_attivita")),
            _row("P. IVA", field("piva")),
            _row("Codice SDI", field("sdi")),
            _row("PEC", field("pec")),
            _row("Email", field("email")),
            _row("Telefono", field("telefono")),

            const SizedBox(height: 20),
            _sectionTitle("Indirizzo"),
            _row("Paese", field("paese")),
            _row("Via", field("via")),
            _row("Numero civico", field("numero_civico")),
            _row("Città", field("citta")),
            _row("Provincia", field("provincia")),
            _row("CAP", field("cap")),
            if (mapPoint != null) ...[
              const SizedBox(height: 12),
              _sectionTitle("Posizione"),
              SizedBox(
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(
                      target: mapPoint,
                      zoom: 16,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('activity_location'),
                        position: mapPoint,
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationEnabled: false,
                    compassEnabled: true,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    onApprove();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text("Approva"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    onReject();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text("Rifiuta"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? "-" : value),
          ),
        ],
      ),
    );
  }

  LatLng? _extractPoint() {
    final double? lat = _asDouble(
      data['lat'] ??
          data['latitude'] ??
          data['latitudine'] ??
          data['coord_lat'] ??
          data['location_lat'],
    );
    final double? lng = _asDouble(
      data['lng'] ??
          data['lon'] ??
          data['long'] ??
          data['longitude'] ??
          data['longitudine'] ??
          data['coord_lng'] ??
          data['location_lng'],
    );

    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final String normalized = value.toString().trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }
}
