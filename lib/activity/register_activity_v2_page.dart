// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/theme/app_colors.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/hive/hive_register_activity.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/logiche/requests/activity_photos_service.dart';
import 'package:tipicooo/hive/hive_photos_controller.dart';
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'widgets/add_photo_box.dart';
import 'upload_picker.dart';

enum UserRoleType { owner, association, delegate }

class RegisterActivityV2Page extends StatefulWidget {
  const RegisterActivityV2Page({super.key});

  @override
  State<RegisterActivityV2Page> createState() => _RegisterActivityV2PageState();
}

class _RegisterActivityV2PageState extends State<RegisterActivityV2Page>
    with SingleTickerProviderStateMixin {
  UserRoleType? _roleType;
  int _step = 0;
  final Map<String, TextEditingController> _controllers = {};
  final GlobalKey<FormState> _formKeyOwner = GlobalKey<FormState>();
  late final AnimationController _submittedController;
  late final HivePhotosController _photosController;
  bool _isSubmitting = false;
  bool _isDeletingActivity = false;
  String? _requestId;
  String? _currentStatus;
  bool _photosCompleted = false;
  bool _isEditingExisting = false;
  bool _loadingActivities = false;
  bool _isDisposing = false;
  List<Map<String, dynamic>> _userActivities = [];
  bool? _hasPrivateParking;
  bool? _truckParkingAllowed;
  bool? _hasShowers;
  Set<String> _guestParkingOptions = <String>{};
  Set<String> _businessLunchSlots = <String>{};

  bool _handleStepBack() {
    if (_step > 0 && _step < 3) {
      setState(() => _step -= 1);
      return true;
    }
    if (_step == 4) {
      setState(() => _step = 1);
      return true;
    }
    if (_step == 5) {
      setState(() => _step = 4);
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _submittedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _photosController = HivePhotosController();
    for (final key in [
      'insegna',
      'ragione_sociale',
      'piva',
      'sdi',
      'pec',
      'email',
      'telefono',
      'paese',
      'via',
      'numero_civico',
      'citta',
      'provincia',
      'cap',
      'categoria',
      'numero_stelle',
      'descrizione',
      'truck_parking_capacity',
      'guest_parking_other_text',
    ]) {
      _controllers[key] = TextEditingController(
        text: (HiveRegisterActivity.loadField(key) ?? "").toString(),
      );
    }
    _hasPrivateParking = _readHiveBool('has_private_parking');
    _truckParkingAllowed = _readHiveBool('truck_parking_allowed');
    _hasShowers = _readHiveBool('has_showers');
    _guestParkingOptions = _readHiveStringList('guest_parking_options').toSet();
    _businessLunchSlots = _readHiveStringList('business_lunch_slots').toSet();
    _requestId = HiveRegisterActivity.loadField('requestId')?.toString();
    final openPhotos = HiveRegisterActivity.loadField('open_photos') == true;
    if (openPhotos) {
      _step = 4;
      HiveRegisterActivity.saveField('open_photos', false);
    }
    _loadUserActivities();
    _syncRequestStatus();
  }

  bool _hasLogoAndMinimumPhotos({
    String? logoKey,
    List<dynamic>? rawPhotoKeys,
    Map<String, dynamic>? item,
  }) {
    final logo =
        (logoKey ??
                item?["logo"]?.toString() ??
                item?["logoKey"]?.toString() ??
                HiveRegisterActivity.loadField('logo')?.toString() ??
                "")
            .trim();
    if (logo.isEmpty) return false;

    final source =
        rawPhotoKeys ??
        (item?["photoKeys"] as List?) ??
        (item?["photo_keys"] as List?) ??
        (HiveRegisterActivity.loadField('photo_keys') as List? ?? <dynamic>[]);

    final photoCount = source
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .length;
    return photoCount >= 5;
  }

  Future<void> _loadUserActivities() async {
    setState(() => _loadingActivities = true);
    final items = await ActivityRequestService.fetchUserActivities();
    if (!mounted) return;
    _userActivities = items;
    _loadingActivities = false;
    setState(() {});
  }

  Future<void> _syncRequestStatus() async {
    final result = await ActivityRequestService.fetchLatestStatus();
    if (result == null) {
      if (_requestId != null && _requestId!.isNotEmpty) {
        _requestId = null;
        HiveRegisterActivity.saveField('requestId', '');
      }
      _currentStatus = null;
      _photosCompleted = false;
      return;
    }

    final rid = (result["requestId"] ?? "").toString();
    _currentStatus = (result["status"] ?? "").toString();
    if (rid.isNotEmpty) {
      _requestId = rid;
      HiveRegisterActivity.saveField('requestId', rid);
      await _loadRequestDetail(rid);
      // Non forzare lo step automaticamente: l'utente potrebbe essere entrato
      // per modificare dati (step 1). L'unico jump "guidato" e' quello gestito
      // da `open_photos` in initState (notifica).
      if (_currentStatus == "approved") {
        _isEditingExisting = true;
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadRequestDetail(String requestId) async {
    final item = await ActivityRequestService.fetchRequestDetail(requestId);
    if (!mounted || _isDisposing || item == null) return;
    _currentStatus = (item["status"] ?? _currentStatus ?? "").toString();
    _photosCompleted = _hasLogoAndMinimumPhotos(item: item);

    final logoFromServer = (item["logo"] ?? "").toString().trim();
    if (logoFromServer.isNotEmpty) {
      HiveRegisterActivity.saveField('logo', logoFromServer);
    }

    final rawPhotoKeys = item["photoKeys"];
    if (rawPhotoKeys is List) {
      final keys = rawPhotoKeys
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      HiveRegisterActivity.saveField('photo_keys', keys);
    }

    void saveIfPresent(String key, String field) {
      if (!mounted || _isDisposing) return;
      final value = (item[field] ?? "").toString();
      if (value.isNotEmpty) {
        final controller = _controllers[key];
        if (controller == null) return;
        HiveRegisterActivity.saveField(key, value);
        try {
          controller.text = value;
        } catch (_) {
          return;
        }
      }
    }

    saveIfPresent('insegna', 'insegna');
    saveIfPresent('ragione_sociale', 'ragione_sociale');
    saveIfPresent('piva', 'piva');
    saveIfPresent('sdi', 'sdi');
    saveIfPresent('pec', 'pec');
    saveIfPresent('email', 'email');
    saveIfPresent('telefono', 'telefono');
    saveIfPresent('paese', 'paese');
    saveIfPresent('via', 'via');
    saveIfPresent('numero_civico', 'numero_civico');
    saveIfPresent('citta', 'citta');
    saveIfPresent('provincia', 'provincia');
    saveIfPresent('cap', 'cap');
    saveIfPresent('categoria', 'tipo_attivita');
    saveIfPresent('numero_stelle', 'numero_stelle');
    saveIfPresent('numero_stelle', 'numeroStelle');
    saveIfPresent('numero_stelle', 'stars');
    saveIfPresent('descrizione', 'descrizione');
    saveIfPresent('descrizione', 'description');
    _applyLogisticsFromItem(item);
  }

  bool? _readHiveBool(String key) {
    final raw = HiveRegisterActivity.loadField(key);
    if (raw is bool) return raw;
    final value = (raw ?? "").toString().trim().toLowerCase();
    if (value == "true" || value == "1" || value == "si") return true;
    if (value == "false" || value == "0" || value == "no") return false;
    return null;
  }

  List<String> _readHiveStringList(String key) {
    final raw = HiveRegisterActivity.loadField(key);
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final asString = (raw ?? "").toString().trim();
    if (asString.isEmpty) return <String>[];
    return asString
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool? _readItemBool(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final raw = item[key];
      if (raw is bool) return raw;
      final value = (raw ?? "").toString().trim().toLowerCase();
      if (value == "true" || value == "1" || value == "si") return true;
      if (value == "false" || value == "0" || value == "no") return false;
    }
    return null;
  }

  void _applyLogisticsFromItem(Map<String, dynamic> item) {
    final hasPrivateParking = _readItemBool(item, const [
      "has_private_parking",
      "hasPrivateParking",
    ]);
    final truckParkingAllowed = _readItemBool(item, const [
      "truck_parking_allowed",
      "truckParkingAllowed",
    ]);
    final hasBusinessLunch = _readItemBool(item, const [
      "has_business_lunch",
      "hasBusinessLunch",
    ]);
    final hasShowers = _readItemBool(item, const [
      "has_showers",
      "hasShowers",
    ]);
    final truckParkingCapacityRaw =
        (item["truck_parking_capacity"] ?? item["truckParkingCapacity"] ?? "")
            .toString()
            .trim();
    final guestParkingRaw =
        item["guest_parking_options"] ?? item["guestParkingOptions"];
    final guestParking = <String>{
      if (guestParkingRaw is List)
        ...guestParkingRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty),
    };
    final guestParkingOtherText =
        (item["guest_parking_other_text"] ?? item["guestParkingOtherText"] ?? "")
            .toString()
            .trim();
    final lunchSlotsRaw = item["business_lunch_slots"] ?? item["businessLunchSlots"];
    final lunchSlots = <String>{
      if (lunchSlotsRaw is List)
        ...lunchSlotsRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty),
    };

    if (hasPrivateParking != null) {
      _hasPrivateParking = hasPrivateParking;
      HiveRegisterActivity.saveField("has_private_parking", hasPrivateParking);
    }
    if (truckParkingAllowed != null) {
      _truckParkingAllowed = truckParkingAllowed;
      HiveRegisterActivity.saveField(
        "truck_parking_allowed",
        truckParkingAllowed,
      );
    }
    if (hasBusinessLunch != null) {
      HiveRegisterActivity.saveField("has_business_lunch", hasBusinessLunch);
    }
    if (hasShowers != null) {
      _hasShowers = hasShowers;
      HiveRegisterActivity.saveField("has_showers", hasShowers);
    }
    if (truckParkingCapacityRaw.isNotEmpty) {
      _controllers["truck_parking_capacity"]?.text = truckParkingCapacityRaw;
      HiveRegisterActivity.saveField(
        "truck_parking_capacity",
        truckParkingCapacityRaw,
      );
    }
    if (guestParking.isNotEmpty) {
      _guestParkingOptions = guestParking;
      HiveRegisterActivity.saveField(
        "guest_parking_options",
        guestParking.toList(),
      );
    }
    if (guestParkingOtherText.isNotEmpty) {
      _controllers["guest_parking_other_text"]?.text = guestParkingOtherText;
      HiveRegisterActivity.saveField(
        "guest_parking_other_text",
        guestParkingOtherText,
      );
    }
    if (lunchSlots.isNotEmpty) {
      _businessLunchSlots = lunchSlots;
      HiveRegisterActivity.saveField(
        "business_lunch_slots",
        lunchSlots.toList(),
      );
    }
  }

  bool _validateLogisticsSection() {
    if (_hasPrivateParking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Seleziona: Hai un parcheggio privato?"),
        ),
      );
      return false;
    }

    if (_hasPrivateParking == true && _truckParkingAllowed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Seleziona: Gli autoarticolati possono parcheggiare?",
          ),
        ),
      );
      return false;
    }

    if (_truckParkingAllowed == true) {
      final raw = (_controllers["truck_parking_capacity"]?.text ?? "").trim();
      final qty = int.tryParse(raw);
      if (qty == null || qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Inserisci un numero indicativo valido."),
          ),
        );
        return false;
      }
    }

    if (_hasPrivateParking == true && _truckParkingAllowed == true) {
      if (_hasShowers == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Seleziona: Hai le docce?"),
          ),
        );
        return false;
      }
    }

    if (_hasPrivateParking == false && _guestParkingOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Seleziona almeno una opzione: Dove possono parcheggiare gli ospiti?",
          ),
        ),
      );
      return false;
    }

    final hasBusinessLunch = _readHiveBool("has_business_lunch");
    if (hasBusinessLunch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Seleziona: Fai pranzi di lavoro?"),
        ),
      );
      return false;
    }
    if (hasBusinessLunch == true && _businessLunchSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Seleziona almeno una fascia: Mezzogiorno o Sera."),
        ),
      );
      return false;
    }

    return true;
  }

  Map<String, dynamic> _currentLogisticsPayload() {
    final truckCapacity = (_controllers["truck_parking_capacity"]?.text ?? "")
        .trim();
    final guestOther = (_controllers["guest_parking_other_text"]?.text ?? "")
        .trim();
    final hasBusinessLunch = _readHiveBool("has_business_lunch");
    return <String, dynamic>{
      "has_private_parking": _hasPrivateParking,
      "truck_parking_allowed":
          _hasPrivateParking == true ? _truckParkingAllowed : null,
      "truck_parking_capacity":
          _truckParkingAllowed == true ? truckCapacity : "",
      "guest_parking_options":
          _hasPrivateParking == false ? _guestParkingOptions.toList() : <String>[],
      "guest_parking_other_text":
          (_hasPrivateParking == false && _guestParkingOptions.contains("altro"))
          ? guestOther
          : "",
      "has_showers":
          (_hasPrivateParking == true && _truckParkingAllowed == true)
          ? _hasShowers
          : null,
      "numero_stelle":
          int.tryParse((_controllers["numero_stelle"]?.text ?? "").trim()),
      "has_business_lunch": hasBusinessLunch,
      "business_lunch_slots": hasBusinessLunch == true
          ? _businessLunchSlots.toList()
          : <String>[],
    };
  }

  Future<void> _deleteCurrentActivity({required VoidCallback onDeleted}) async {
    if (_isDeletingActivity) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Elimina attività"),
        content: const Text(
          "Sei sicuro di voler eliminare la registrazione? Questa azione non si può annullare.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annulla"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Elimina"),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (_requestId == null || _requestId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Attività non valida da eliminare.")),
        );
      }
      return;
    }

    setState(() => _isDeletingActivity = true);
    final deleted = await ActivityRequestService.deleteActivityRequest(
      _requestId!,
    );
    if (!mounted) return;
    setState(() => _isDeletingActivity = false);

    if (deleted) {
      HiveRegisterActivity.clearAll();
      Provider.of<HivePhotosController>(context, listen: false).clearAll();
      onDeleted();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Errore eliminazione attività.")),
    );
  }

  void _removePhotoAt(int index, HivePhotosController controller) {
    final existing =
        (HiveRegisterActivity.loadField('photo_keys') as List?) ?? [];
    final keys = existing.map((e) => e.toString()).toList();
    String? oldKey;
    if (index >= 0 && index < keys.length) {
      oldKey = keys[index];
      keys.removeAt(index);
      HiveRegisterActivity.saveField('photo_keys', keys);
    }

    // Preview locale non affidabile su mobile: aggiorniamo solo lo storage interno.
    controller.loadPhotos();
    if (_requestId != null &&
        _requestId!.isNotEmpty &&
        oldKey != null &&
        oldKey.isNotEmpty) {
      ActivityPhotosService.deletePhoto(requestId: _requestId!, key: oldKey);
    }
  }

  Future<void> _replacePhotoAt(
    int index,
    HivePhotosController controller,
  ) async {
    final result = await pickImage();
    if (result == null) return;
    if (_requestId == null || _requestId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invia prima l'adesione.")),
        );
      }
      return;
    }

    final upload = await ActivityPhotosService.uploadFromPickerResult(
      pickerResult: result,
      requestId: _requestId!,
      kind: "photo",
    );

    if (upload == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Errore upload foto.")));
      }
      return;
    }

    final key = upload["key"] ?? "";
    if (key.isEmpty) return;

    final existing =
        (HiveRegisterActivity.loadField('photo_keys') as List?) ?? [];
    final keys = existing.map((e) => e.toString()).toList();
    String? oldKey;
    if (index >= 0 && index < keys.length) {
      oldKey = keys[index];
      keys[index] = key;
    } else {
      keys.add(key);
    }
    HiveRegisterActivity.saveField('photo_keys', keys);

    // Preview locale non affidabile su mobile: aggiorniamo solo lo storage interno.
    controller.loadPhotos();

    if (_requestId != null &&
        _requestId!.isNotEmpty &&
        oldKey != null &&
        oldKey.isNotEmpty) {
      ActivityPhotosService.deletePhoto(requestId: _requestId!, key: oldKey);
    }
  }

  void _openNetworkImagePreview(String imageUrl) {
    final url = imageUrl.trim();
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposing = true;
    _submittedController.dispose();
    _photosController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetForNewActivity() {
    _isEditingExisting = false;
    _requestId = null;
    _currentStatus = null;
    _photosCompleted = false;

    HiveRegisterActivity.saveField('requestId', '');
    HiveRegisterActivity.saveField('logo', '');
    HiveRegisterActivity.saveField('logo_preview', '');
    HiveRegisterActivity.saveField('photo_keys', <String>[]);
    HiveRegisterActivity.saveField('open_photos', false);
    HiveRegisterActivity.saveField('has_private_parking', null);
    HiveRegisterActivity.saveField('truck_parking_allowed', null);
    HiveRegisterActivity.saveField('truck_parking_capacity', '');
    HiveRegisterActivity.saveField('has_business_lunch', null);
    HiveRegisterActivity.saveField('has_showers', null);
    HiveRegisterActivity.saveField('guest_parking_options', <String>[]);
    HiveRegisterActivity.saveField('guest_parking_other_text', '');
    HiveRegisterActivity.saveField('business_lunch_slots', <String>[]);
    _hasPrivateParking = null;
    _truckParkingAllowed = null;
    _hasShowers = null;
    _guestParkingOptions = <String>{};
    _businessLunchSlots = <String>{};

    for (final key in _controllers.keys) {
      HiveRegisterActivity.saveField(key, '');
      final controller = _controllers[key];
      if (controller != null) {
        controller.text = '';
      }
    }

    _photosController.clearAll();
  }

  Widget _roleButton({required String label, required UserRoleType value}) {
    final isSelected = _roleType == value;

    return InkWell(
      onTap: () => setState(() {
        _roleType = value;
        _step = 1;
        _resetForNewActivity();
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: isSelected ? AppColors.primaryBlue : AppColors.black,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleInfo() {
    if (_roleType == null) return const SizedBox.shrink();

    switch (_roleType!) {
      case UserRoleType.owner:
        return const Text(
          "Sei proprietario o gestore dell’attività.",
          style: AppTextStyles.body,
        );
      case UserRoleType.association:
        return const Text(
          "Rappresenti un’associazione o un ente.",
          style: AppTextStyles.body,
        );
      case UserRoleType.delegate:
        return const Text(
          "Sei responsabile o dipendente incaricato.",
          style: AppTextStyles.body,
        );
    }
  }

  Widget _buildInputBox({
    required String label,
    required String keyName,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    String? hintText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        controller: _controllers[keyName],
        keyboardType: keyboardType,
        readOnly: readOnly,
        validator: validator,
        onChanged: (value) => HiveRegisterActivity.saveField(keyName, value),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildOwnerStep() {
    if ((_controllers['paese']?.text ?? "").trim().isEmpty) {
      _controllers['paese']?.text = "Italia";
      HiveRegisterActivity.saveField('paese', "Italia");
    }

    String? requiredText(String? value, String fieldLabel) {
      if (value == null || value.trim().isEmpty) {
        return "Inserisci $fieldLabel";
      }
      return null;
    }

    String? validatePiva(String? value) {
      if (value == null || value.trim().isEmpty) {
        return "Inserisci P. IVA";
      }
      final digits = value.replaceAll(RegExp(r'\\s+'), '');
      if (!RegExp(r'^\\d{11}$').hasMatch(digits)) {
        return "P. IVA deve avere 11 цифre";
      }
      return null;
    }

    String? validateCap(String? value) {
      if (value == null || value.trim().isEmpty) {
        return "Inserisci CAP";
      }
      final digits = value.replaceAll(RegExp(r'\\s+'), '');
      if (!RegExp(r'^\\d{5}$').hasMatch(digits)) {
        return "CAP deve avere 5 цифre";
      }
      return null;
    }

    String? validatePhone(String? value) {
      if (value == null || value.trim().isEmpty) {
        return "Inserisci telefono";
      }
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 8) {
        return "Telefono non valido";
      }
      return null;
    }

    String? validateEmail(String? value, String label) {
      if (value == null || value.trim().isEmpty) {
        return "Inserisci $label";
      }
      final email = value.trim();
      if (!RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$').hasMatch(email)) {
        return "$label non valida";
      }
      return null;
    }

    String? validateSdi(String? value) {
      if (value == null || value.trim().isEmpty) return null;
      final trimmed = value.trim();
      if (trimmed.length != 7) {
        return "Codice SDI deve avere 7 caratteri";
      }
      return null;
    }

    String? validateStars(String? value) {
      if (value == null || value.trim().isEmpty) return null;
      final stars = int.tryParse(value.trim());
      if (stars == null || stars < 1 || stars > 5) {
        return "Inserisci un numero da 1 a 5";
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Dati attività",
          style: AppTextStyles.sectionTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _buildInputBox(
          label: "Tipo attività",
          keyName: 'categoria',
          hintText: "La tipologia verrà usata per la ricerca",
          validator: (v) => requiredText(v, "la categoria"),
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "Numero stelle",
          keyName: 'numero_stelle',
          hintText: "Da 1 a 5",
          keyboardType: TextInputType.number,
          validator: validateStars,
        ),
        const SizedBox(height: 12),

        _buildInputBox(
          label: "Insegna attività",
          keyName: 'insegna',
          hintText: "Nome attività",
          validator: (v) => requiredText(v, "l'insegna"),
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "Ragione sociale",
          keyName: 'ragione_sociale',
          validator: (v) => requiredText(v, "la ragione sociale"),
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "P. IVA",
          keyName: 'piva',
          keyboardType: TextInputType.number,
          validator: validatePiva,
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "Codice SDI",
          keyName: 'sdi',
          validator: validateSdi,
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "PEC",
          keyName: 'pec',
          keyboardType: TextInputType.emailAddress,
          validator: (v) => validateEmail(v, "PEC"),
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "Email",
          keyName: 'email',
          keyboardType: TextInputType.emailAddress,
          validator: (v) => validateEmail(v, "Email"),
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "Telefono",
          keyName: 'telefono',
          keyboardType: TextInputType.phone,
          validator: validatePhone,
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "Paese",
          keyName: 'paese',
          readOnly: true,
          validator: (v) => requiredText(v, "il paese"),
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "Via",
          keyName: 'via',
          validator: (v) => requiredText(v, "la via"),
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "Numero civico",
          keyName: 'numero_civico',
          validator: (v) => requiredText(v, "il numero civico"),
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "Città",
          keyName: 'citta',
          validator: (v) => requiredText(v, "la città"),
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "Provincia",
          keyName: 'provincia',
          validator: (v) => requiredText(v, "la provincia"),
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: "CAP",
          keyName: 'cap',
          keyboardType: TextInputType.number,
          validator: validateCap,
        ),
        const SizedBox(height: 12),
        const Text(
          "Hai un parcheggio privato?",
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            ChoiceChip(
              label: const Text("Si"),
              selected: _hasPrivateParking == true,
              onSelected: (_) {
                setState(() {
                  _hasPrivateParking = true;
                  _guestParkingOptions = <String>{};
                  _controllers["guest_parking_other_text"]?.text = '';
                  HiveRegisterActivity.saveField('has_private_parking', true);
                  HiveRegisterActivity.saveField(
                    'guest_parking_options',
                    <String>[],
                  );
                  HiveRegisterActivity.saveField(
                    'guest_parking_other_text',
                    '',
                  );
                });
              },
            ),
            ChoiceChip(
              label: const Text("No"),
              selected: _hasPrivateParking == false,
              onSelected: (_) {
                setState(() {
                  _hasPrivateParking = false;
                  _truckParkingAllowed = null;
                  _hasShowers = null;
                  _controllers["truck_parking_capacity"]?.text = '';
                  HiveRegisterActivity.saveField('has_private_parking', false);
                  HiveRegisterActivity.saveField('truck_parking_allowed', null);
                  HiveRegisterActivity.saveField('truck_parking_capacity', '');
                  HiveRegisterActivity.saveField('has_showers', null);
                  _guestParkingOptions = <String>{};
                  _controllers["guest_parking_other_text"]?.text = '';
                  HiveRegisterActivity.saveField(
                    'guest_parking_options',
                    <String>[],
                  );
                  HiveRegisterActivity.saveField(
                    'guest_parking_other_text',
                    '',
                  );
                });
              },
            ),
          ],
        ),
        if (_hasPrivateParking == false) ...[
          const SizedBox(height: 12),
          const Text(
            "Dove possono parcheggiare gli ospiti?",
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in const <String>[
                "Strada",
                "Parcheggio pubblico",
                "Piazza",
                "Altro",
              ])
                FilterChip(
                  label: Text(option),
                  selected: _guestParkingOptions.contains(option),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _guestParkingOptions.add(option);
                      } else {
                        _guestParkingOptions.remove(option);
                        if (option == "Altro") {
                          _controllers["guest_parking_other_text"]?.text = '';
                          HiveRegisterActivity.saveField(
                            'guest_parking_other_text',
                            '',
                          );
                        }
                      }
                      HiveRegisterActivity.saveField(
                        'guest_parking_options',
                        _guestParkingOptions.toList(),
                      );
                    });
                  },
                ),
            ],
          ),
          if (_guestParkingOptions.contains("Altro")) ...[
            const SizedBox(height: 12),
            _buildInputBox(
              label: "Altro (specifica)",
              keyName: 'guest_parking_other_text',
            ),
          ],
        ],
        if (_hasPrivateParking == true) ...[
          const SizedBox(height: 12),
          const Text(
            "Gli autoarticolati possono parcheggiare?",
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: const Text("Si"),
                selected: _truckParkingAllowed == true,
                onSelected: (_) {
                  setState(() {
                    _truckParkingAllowed = true;
                    HiveRegisterActivity.saveField(
                      'truck_parking_allowed',
                      true,
                    );
                  });
                },
              ),
              ChoiceChip(
                label: const Text("No"),
                selected: _truckParkingAllowed == false,
                onSelected: (_) {
                setState(() {
                  _truckParkingAllowed = false;
                  _hasShowers = null;
                  _controllers["truck_parking_capacity"]?.text = '';
                  HiveRegisterActivity.saveField(
                    'truck_parking_allowed',
                      false,
                    );
                  HiveRegisterActivity.saveField(
                    'truck_parking_capacity',
                    '',
                  );
                  HiveRegisterActivity.saveField('has_showers', null);
                });
              },
            ),
          ],
        ),
          if (_truckParkingAllowed == true) ...[
            const SizedBox(height: 12),
            _buildInputBox(
              label: "Quanti? (Numero indicativo)",
              keyName: 'truck_parking_capacity',
              keyboardType: TextInputType.number,
            ),
          ],
        ],
        if (_hasPrivateParking == true && _truckParkingAllowed == true) ...[
          const SizedBox(height: 12),
          const Text(
            "Hai le docce?",
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: const Text("Si"),
                selected: _hasShowers == true,
                onSelected: (_) {
                  setState(() {
                    _hasShowers = true;
                    HiveRegisterActivity.saveField('has_showers', true);
                  });
                },
              ),
              ChoiceChip(
                label: const Text("No"),
                selected: _hasShowers == false,
                onSelected: (_) {
                  setState(() {
                    _hasShowers = false;
                    HiveRegisterActivity.saveField('has_showers', false);
                  });
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          "Fai pranzi di lavoro?",
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            ChoiceChip(
              label: const Text("Si"),
              selected: _readHiveBool('has_business_lunch') == true,
              onSelected: (_) {
                setState(() {
                  HiveRegisterActivity.saveField('has_business_lunch', true);
                });
              },
            ),
            ChoiceChip(
              label: const Text("No"),
              selected: _readHiveBool('has_business_lunch') == false,
              onSelected: (_) {
                setState(() {
                  HiveRegisterActivity.saveField('has_business_lunch', false);
                  _businessLunchSlots = <String>{};
                  HiveRegisterActivity.saveField(
                    'business_lunch_slots',
                    <String>[],
                  );
                });
              },
            ),
          ],
        ),
        if (_readHiveBool('has_business_lunch') == true) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final slot in const <String>["Mezzogiorno", "Sera"])
                FilterChip(
                  label: Text(slot),
                  selected: _businessLunchSlots.contains(slot),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _businessLunchSlots.add(slot);
                      } else {
                        _businessLunchSlots.remove(slot);
                      }
                      HiveRegisterActivity.saveField(
                        'business_lunch_slots',
                        _businessLunchSlots.toList(),
                      );
                    });
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const SizedBox(height: 22),

        BlueNarrowButton(
          label: _isEditingExisting
              ? "Salva modifica"
              : "Continua ai documenti",
          icon: Icons.arrow_forward,
          onPressed: () {
            if (!_validateLogisticsSection()) return;
            if (_isEditingExisting) {
              if (_currentStatus == "approved") {
                setState(() => _step = 4);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Le fasi documenti non sono disponibili in modifica.",
                    ),
                  ),
                );
              }
              return;
            }
            setState(() => _step = 2);
          },
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () async {
            if ((_requestId ?? "").trim().isNotEmpty) {
              await _deleteCurrentActivity(
                onDeleted: () async {
                  if (!mounted) return;
                  await _loadUserActivities();
                  if (!mounted) return;
                  setState(() {
                    _step = 0;
                    _requestId = null;
                    _currentStatus = null;
                    _isEditingExisting = false;
                    _photosCompleted = false;
                  });
                },
              );
              return;
            }

            final bool? confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Annulla registrazione"),
                content: const Text(
                  "Questa azione elimina tutti i dati inseriti e non può essere annullata. Confermi?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Torna indietro"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Conferma annullamento"),
                  ),
                ],
              ),
            );
            if (confirm != true) return;

            HiveRegisterActivity.clearAll();
            for (final controller in _controllers.values) {
              controller.text = "";
            }
            setState(() {
              _hasPrivateParking = null;
              _truckParkingAllowed = null;
              _hasShowers = null;
              _step = 0;
              _roleType = null;
            });
          },
          child: const Text("Annulla registrazione", style: AppTextStyles.body),
        ),
      ],
    );
  }

  Widget _uploadBox({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.body)),
        ],
      ),
    );
  }

  Widget _buildOwnerDocumentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Documenti richiesti",
          style: AppTextStyles.sectionTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          "Carica i documenti per la verifica dell’attività.",
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),

        _uploadBox(label: "Visura camerale (PDF)"),
        const SizedBox(height: 12),
        _uploadBox(label: "Carta d’identità (PDF/JPG)"),
        const SizedBox(height: 12),
        _uploadBox(
          label: "Codice fiscale (se non presente sulla carta d’identità)",
        ),
        const SizedBox(height: 22),

        BlueNarrowButton(
          label: "Invia adesione",
          icon: Icons.send,
          onPressed: _isSubmitting
              ? () {}
              : () async {
                  // Protezione anti doppio tap: evita invii duplicati ravvicinati.
                  if (_isSubmitting) return;
                  if ((_requestId ?? "").trim().isNotEmpty &&
                      (_currentStatus ?? "").trim().toLowerCase() ==
                          "pending") {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Richiesta già inviata e in attesa."),
                      ),
                    );
                    setState(() => _step = 3);
                    return;
                  }
                  setState(() => _isSubmitting = true);

                  final payload = {
                    "roleType": "owner",
                    "insegna": _controllers["insegna"]?.text.trim(),
                    "ragione_sociale": _controllers["ragione_sociale"]?.text
                        .trim(),
                    "piva": _controllers["piva"]?.text.trim(),
                    "sdi": _controllers["sdi"]?.text.trim(),
                    "pec": _controllers["pec"]?.text.trim(),
                    "email": _controllers["email"]?.text.trim(),
                    "telefono": _controllers["telefono"]?.text.trim(),
                    "paese": _controllers["paese"]?.text.trim(),
                    "via": _controllers["via"]?.text.trim(),
                    "numero_civico": _controllers["numero_civico"]?.text.trim(),
                    "citta": _controllers["citta"]?.text.trim(),
                    "provincia": _controllers["provincia"]?.text.trim(),
                    "cap": _controllers["cap"]?.text.trim(),
                    "tipo_attivita": _controllers["categoria"]?.text.trim(),
                    "numero_stelle": int.tryParse(
                      (_controllers["numero_stelle"]?.text ?? "").trim(),
                    ),
                    "has_private_parking": _hasPrivateParking,
                    "truck_parking_allowed": _hasPrivateParking == true
                        ? _truckParkingAllowed
                        : null,
                    "truck_parking_capacity": _truckParkingAllowed == true
                        ? int.tryParse(
                            (_controllers["truck_parking_capacity"]?.text ?? "")
                                .trim(),
                          )
                        : null,
                    "guest_parking_options": _hasPrivateParking == false
                        ? _guestParkingOptions.toList()
                        : null,
                    "guest_parking_other_text":
                        (_hasPrivateParking == false &&
                            _guestParkingOptions.contains("Altro"))
                        ? (_controllers["guest_parking_other_text"]?.text ?? "")
                            .trim()
                        : null,
                    "has_showers":
                        (_hasPrivateParking == true &&
                            _truckParkingAllowed == true)
                        ? _hasShowers
                        : null,
                    "has_business_lunch": _readHiveBool("has_business_lunch"),
                    "business_lunch_slots": _readHiveBool("has_business_lunch") ==
                            true
                        ? _businessLunchSlots.toList()
                        : <String>[],
                  };

                  final requestId =
                      await ActivityRequestService.sendActivityRequest(payload);

                  if (!mounted) return;

                  if (requestId != null && requestId.isNotEmpty) {
                    _requestId = requestId;
                    HiveRegisterActivity.saveField('requestId', requestId);
                    NotificationController.instance.addNotification(
                      AppNotification(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: "Richiesta registrazione inviata",
                        message:
                            "Grazie per aver registrato la Tua attività su tipic.ooo, ti comunicheremo l'avvenuta registrazione dopo l'approvazione.",
                        timestamp: DateTime.now(),
                      ),
                    );
                    setState(() => _step = 3);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Errore invio adesione. Riprova."),
                      ),
                    );
                  }

                  setState(() => _isSubmitting = false);
                },
        ),
      ],
    );
  }

  Widget _buildPhotosStep(BuildContext context) {
    final logoKey = HiveRegisterActivity.loadField('logo')?.toString();
    if (_currentStatus != "approved") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Text(
            "Foto attività",
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            "Potrai caricare le foto solo dopo l'approvazione da parte di Tipic.ooo office.",
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Foto attività",
          style: AppTextStyles.sectionTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          "Stile tipo Booking: foto chiare, ben illuminate e rappresentative.",
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.photo, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              if (logoKey != null &&
                  logoKey.isNotEmpty &&
                  _requestId != null &&
                  _requestId!.isNotEmpty)
                FutureBuilder<String?>(
                  future: ActivityRequestService.fetchPhotoUrl(
                    requestId: _requestId!,
                    key: logoKey,
                  ),
                  builder: (context, snapshot) {
                    final url = (snapshot.data ?? "").trim();
                    if (url.isEmpty) return const SizedBox.shrink();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _openNetworkImagePreview(url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    );
                  },
                ),
              Expanded(
                child: Text(
                  (logoKey == null || logoKey.isEmpty)
                      ? "Logo (facoltativo)"
                      : "Logo caricato",
                  style: AppTextStyles.body,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final result = await pickImage();
                  if (result == null) return;
                  if (_requestId == null || _requestId!.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Invia prima l'adesione."),
                        ),
                      );
                    }
                    return;
                  }

                  final upload =
                      await ActivityPhotosService.uploadFromPickerResult(
                        pickerResult: result,
                        requestId: _requestId!,
                        kind: "logo",
                      );

                  if (upload == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Errore upload logo.")),
                      );
                    }
                    return;
                  }

                  final newLogoKey = upload["key"] ?? "";
                  final oldLogoKey = logoKey ?? "";
                  HiveRegisterActivity.saveField('logo', newLogoKey);
                  if (_requestId != null &&
                      _requestId!.isNotEmpty &&
                      oldLogoKey.isNotEmpty &&
                      oldLogoKey != newLogoKey) {
                    ActivityPhotosService.deletePhoto(
                      requestId: _requestId!,
                      key: oldLogoKey,
                    );
                  }
                  if (mounted) setState(() {});
                },
                child: const Text("Carica"),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        const Text(
          "Carica logo + almeno 5 foto (max 10)",
          style: AppTextStyles.sectionTitle,
        ),
        const SizedBox(height: 6),
        const Text(
          "Formati: JPG, JPEG, PNG — Min 1200px lato lungo — Min 800px altezza — Max 5MB",
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 6),
        Consumer<HivePhotosController>(
          builder: (context, controller, _) {
            final keysRaw =
                (HiveRegisterActivity.loadField('photo_keys') as List?) ?? [];
            final uploadedCount = keysRaw.length;
            if (uploadedCount == 0) return const SizedBox.shrink();
            final doneText = uploadedCount >= 5 ? " (minimo raggiunto)" : "";
            return Text(
              "Foto gia caricate: $uploadedCount/10$doneText",
              style: AppTextStyles.body,
            );
          },
        ),
        const SizedBox(height: 16),

        Consumer<HivePhotosController>(
          builder: (context, controller, _) {
            final keysRaw =
                (HiveRegisterActivity.loadField('photo_keys') as List?) ?? [];
            final uploadedCount = keysRaw.length;
            final photoKeys = keysRaw
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
            final requestId = (_requestId ?? "").trim();
            return GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < photoKeys.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FutureBuilder<String?>(
                          future: requestId.isEmpty
                              ? Future.value(null)
                              : ActivityRequestService.fetchPhotoUrl(
                                  requestId: requestId,
                                  key: photoKeys[i],
                                ),
                          builder: (context, snapshot) {
                            final url = (snapshot.data ?? "").trim();
                            if (url.isEmpty) {
                              return Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.photo,
                                  size: 36,
                                  color: Colors.black54,
                                ),
                              );
                            }
                            return GestureDetector(
                              onTap: () => _openNetworkImagePreview(url),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.photo,
                                    size: 36,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _removePhotoAt(i, controller),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _replacePhotoAt(i, controller),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                if (uploadedCount < 10)
                  AddPhotoBox(
                    onTap: () async {
                      final result = await pickImage();
                      if (result == null) return;
                      if (_requestId == null || _requestId!.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Invia prima l'adesione."),
                            ),
                          );
                        }
                        return;
                      }

                      final upload =
                          await ActivityPhotosService.uploadFromPickerResult(
                            pickerResult: result,
                            requestId: _requestId!,
                            kind: "photo",
                          );

                      if (upload == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Errore upload foto."),
                            ),
                          );
                        }
                        return;
                      }

                      final key = upload["key"] ?? "";
                      if (key.isNotEmpty) {
                        final existing =
                            (HiveRegisterActivity.loadField('photo_keys')
                                as List?) ??
                            [];
                        final keys = existing.map((e) => e.toString()).toList();
                        if (!keys.contains(key)) {
                          keys.add(key);
                          HiveRegisterActivity.saveField('photo_keys', keys);
                        }
                        if (mounted) setState(() {});
                      }
                    },
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 16),
        Consumer<HivePhotosController>(
          builder: (context, controller, _) {
            return BlueNarrowButton(
              label: "Salva foto",
              icon: Icons.check,
              onPressed: () async {
                final keysRaw =
                    (HiveRegisterActivity.loadField('photo_keys') as List?) ??
                    [];
                final photoKeys = keysRaw.map((e) => e.toString()).toList();
                final photoCount = photoKeys.length;

                if ((logoKey ?? "").trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Carica prima il logo per completare la registrazione.",
                      ),
                    ),
                  );
                  return;
                }

                if (photoCount < 5) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Carica almeno 5 foto per completare la registrazione.",
                      ),
                    ),
                  );
                  return;
                }
                if (_requestId == null || _requestId!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invia prima l'adesione.")),
                  );
                  return;
                }

                final ok = await ActivityRequestService.saveActivityPhotos(
                  requestId: _requestId!,
                  logoKey: logoKey,
                  photoKeys: photoKeys,
                  logistics: _currentLogisticsPayload(),
                );

                if (!mounted) return;
                if (ok) {
                  final publishReadyNow = _hasLogoAndMinimumPhotos(
                    logoKey: logoKey,
                    rawPhotoKeys: photoKeys,
                  );
                  final reachedMinimumNow =
                      !_photosCompleted && publishReadyNow;
                  final remaining = (10 - photoCount).clamp(0, 10);
                  final extraText = remaining > 0
                      ? "Puoi aggiungere ancora $remaining foto."
                      : "Hai raggiunto il massimo di 10 foto.";
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Foto salvate. $extraText")),
                  );
                  if (reachedMinimumNow) {
                    NotificationController.instance.addNotification(
                      AppNotification(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: "Foto minime caricate",
                        message:
                            "Perfetto! Hai caricato le prime 5 foto. Ricorda che puoi caricarne fino a 10.",
                        timestamp: DateTime.now(),
                      ),
                    );
                  }
                  setState(() {
                    _photosCompleted = publishReadyNow;
                    _step = 5;
                  });
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? "Foto salvate." : "Errore salvataggio foto.",
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 10),
        BlueNarrowButton(
          label: "Avanti senza modificare foto",
          icon: Icons.arrow_forward,
          onPressed: () {
            final keysRaw =
                (HiveRegisterActivity.loadField('photo_keys') as List?) ?? [];
            final canProceed = _photosCompleted ||
                _hasLogoAndMinimumPhotos(
                  logoKey: logoKey,
                  rawPhotoKeys: keysRaw,
                );

            if (!canProceed) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Per proseguire servono logo e almeno 5 foto gia caricate.",
                  ),
                ),
              );
              return;
            }

            setState(() => _step = 5);
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Descrizione attività",
          style: AppTextStyles.sectionTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          "Aggiungi una descrizione: verrà mostrata nella scheda mappa.",
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextFormField(
            controller: _controllers['descrizione'],
            minLines: 4,
            maxLines: 6,
            onChanged: (value) =>
                HiveRegisterActivity.saveField('descrizione', value),
            decoration: const InputDecoration(
              labelText: "Inserisci una descrizione",
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        BlueNarrowButton(
          label: "Salva descrizione",
          icon: Icons.check,
          onPressed: () async {
            final description = (_controllers['descrizione']?.text ?? "")
                .trim();
            if (description.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Inserisci una descrizione.")),
              );
              return;
            }
            if (_requestId == null || _requestId!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Invia prima l'adesione.")),
              );
              return;
            }

            final logoKey = HiveRegisterActivity.loadField('logo')?.toString();
            final keysRaw =
                (HiveRegisterActivity.loadField('photo_keys') as List?) ?? [];
            final photoKeys = keysRaw.map((e) => e.toString()).toList();
            final ok = await ActivityRequestService.saveActivityPhotos(
              requestId: _requestId!,
              logoKey: logoKey,
              photoKeys: photoKeys,
              description: description,
              logistics: _currentLogisticsPayload(),
            );

            if (!mounted) return;
            if (ok) {
              HiveRegisterActivity.saveField('descrizione', description);
              NotificationController.instance.addNotification(
                AppNotification(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: "Registrazione completata",
                  message:
                      "Descrizione salvata. La tua attività è pronta per la mappa.",
                  timestamp: DateTime.now(),
                ),
              );
              Navigator.pushReplacementNamed(context, AppRoutes.user);
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Errore salvataggio descrizione.")),
            );
          },
        ),
        const SizedBox(height: 12),
        if (_isDeletingActivity)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ),
          )
        else
          DangerButton(
            label: "Elimina attività",
            icon: Icons.delete_forever,
            onPressed: () => _deleteCurrentActivity(
              onDeleted: () {
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, AppRoutes.user);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSubmittedStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _submittedController,
          builder: (context, child) {
            final t = _submittedController.value;
            final floatY = 4 * (0.5 - (t - 0.5).abs());
            final tilt = (t - 0.5) * 0.06;
            return Opacity(
              opacity: 0.95,
              child: Transform.translate(
                offset: Offset(0, -floatY),
                child: Transform.rotate(angle: tilt, child: child),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(
                      Icons.verified,
                      color: AppColors.primaryBlue,
                      size: 42,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Adesione inviata",
                  style: AppTextStyles.sectionTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "L'adesione è soggetta a controllo da parte dei nostri uffici. "
                  "Riceverai una notifica quando verrà approvata. Grazie!",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PulseDot(delay: 0.0, controller: _submittedController),
                    const SizedBox(width: 6),
                    _PulseDot(delay: 0.2, controller: _submittedController),
                    const SizedBox(width: 6),
                    _PulseDot(delay: 0.4, controller: _submittedController),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildExistingRequestStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Attività in corso",
          style: AppTextStyles.sectionTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          "Hai già una registrazione attiva. Puoi correggere i dati, caricare le foto o eliminare l’attività.",
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        BlueNarrowButton(
          label: "Correggi dati",
          icon: Icons.edit,
          onPressed: () async {
            _roleType ??= UserRoleType.owner;
            if (_requestId != null && _requestId!.isNotEmpty) {
              await _loadRequestDetail(_requestId!);
            }
            if (mounted) {
              setState(() => _step = 1);
            }
          },
        ),
        const SizedBox(height: 12),
        BlueNarrowButton(
          label: "Carica foto",
          icon: Icons.photo_library,
          onPressed: () => setState(() => _step = 4),
        ),
        const SizedBox(height: 12),
        if (_isDeletingActivity)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ),
          )
        else
          DangerButton(
            label: "Elimina attività",
            icon: Icons.delete_forever,
            onPressed: () => _deleteCurrentActivity(
              onDeleted: () {
                if (!mounted) return;
                setState(() {
                  _requestId = null;
                  _step = 0;
                });
              },
            ),
          ),
      ],
    );
  }

  String _activityTitle(Map<String, dynamic> item) {
    final insegna = (item["insegna"] ?? "").toString().trim();
    final ragione = (item["ragione_sociale"] ?? "").toString().trim();
    if (insegna.isNotEmpty) return insegna;
    if (ragione.isNotEmpty) return ragione;
    return (item["requestId"] ?? "Attività").toString();
  }

  String _activityStatusLabel(String status) {
    switch (status) {
      case "approved":
        return "Approvata";
      case "pending":
        return "In attesa";
      case "rejected":
        return "Rifiutata";
      default:
        return status.isEmpty ? "Sconosciuto" : status;
    }
  }

  Color _activityStatusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.green.shade600;
      case "pending":
        return Colors.orange.shade600;
      case "rejected":
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildExistingActivitiesList() {
    if (_loadingActivities) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userActivities.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Text(
            "Le tue attività",
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            "Non hai attività presenti.",
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Le tue attività",
          style: AppTextStyles.sectionTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          "Se hai già una registrazione puoi aprirla per modificare i dati o caricare le foto.",
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        for (final item in _userActivities) ...[
          _buildActivityCard(item),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> item) {
    final status = (item["status"] ?? "").toString();
    final requestId = (item["requestId"] ?? "").toString();
    final title = _activityTitle(item);
    final isRejected = status.toLowerCase() == "rejected";

    return InkWell(
      onTap: () async {
        _roleType ??= UserRoleType.owner;
        if (requestId.isNotEmpty) {
          _requestId = requestId;
          HiveRegisterActivity.saveField('requestId', requestId);
          _currentStatus = status;
          _photosCompleted = _hasLogoAndMinimumPhotos(item: item);
          _isEditingExisting = true;
          await _loadRequestDetail(requestId);
        }
        if (!mounted) return;
        setState(() => _step = 1);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _activityStatusLabel(status),
                    style: AppTextStyles.body.copyWith(
                      color: _activityStatusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isRejected)
              TextButton.icon(
                onPressed: () async {
                  if (requestId.trim().isEmpty) return;
                  _requestId = requestId.trim();
                  _currentStatus = status;
                  await _deleteCurrentActivity(
                    onDeleted: () async {
                      if (!mounted) return;
                      await _loadUserActivities();
                      if (!mounted) return;
                      setState(() {
                        _step = 0;
                        _requestId = null;
                        _currentStatus = null;
                        _isEditingExisting = false;
                        _photosCompleted = false;
                      });
                    },
                  );
                },
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text(
                  "Rimuovi",
                  style: TextStyle(color: Colors.red),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _photosController,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final handled = _handleStepBack();
          if (!handled) {
            Navigator.maybePop(context);
          }
        },
        child: BasePage(
          scrollable: false,
          headerTitle: "Registra attività",
          showBack: _step != 3,
          showHome: true,
          showProfile: true,
          showBell: false,
          showLogout: false,
          onBackPressed: () {
            final handled = _handleStepBack();
            if (!handled) {
              Navigator.maybePop(context);
            }
          },
          body: AppBodyLayout(
            children: [
            if (_step == 0) ...[
              _buildExistingActivitiesList(),
              const SizedBox(height: 24),

              const Text(
                "Chi sei?",
                style: AppTextStyles.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _roleButton(
                      label: "Gestore / Libero professionista",
                      value: UserRoleType.owner,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _roleButton(
                      label: "Associazione/Ente",
                      value: UserRoleType.association,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _roleButton(
                      label: "Responsabile/Dipendente",
                      value: UserRoleType.delegate,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              _roleInfo(),
              const SizedBox(height: 34),
            ],

            if (_step == 1) ...[
              if (_roleType == UserRoleType.owner)
                Form(key: _formKeyOwner, child: _buildOwnerStep())
              else
                const Text(
                  "Step per questo ruolo in arrivo.",
                  style: AppTextStyles.body,
                ),
              const SizedBox(height: 34),
            ],

            if (_step == 2 &&
                !_isEditingExisting &&
                _currentStatus != "approved" &&
                !_photosCompleted) ...[
              _buildOwnerDocumentsStep(),
              const SizedBox(height: 34),
            ],

            if (_step == 3) ...[
              _buildSubmittedStep(),
              const SizedBox(height: 34),
              const SizedBox(height: 20),
            ],

            if (_step == 4) ...[
              _buildPhotosStep(context),
              const SizedBox(height: 34),
            ],

            if (_step == 5) ...[
              _buildDescriptionStep(context),
              const SizedBox(height: 34),
            ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  final double delay;
  final AnimationController controller;

  const _PulseDot({required this.delay, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = (controller.value + delay) % 1.0;
        final scale = 0.7 + (0.3 * (1 - (t - 0.5).abs() * 2));
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
