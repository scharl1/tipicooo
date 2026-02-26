import 'dart:convert';

import 'package:tipicooo/hive/hive_profile.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';

class AffiliateLead {
  const AffiliateLead({
    required this.id,
    required this.suggesterUserId,
    required this.activityName,
    required this.referente,
    required this.activityEmail,
    required this.description,
    required this.createdAtIso,
  });

  final String id;
  final String suggesterUserId;
  final String activityName;
  final String referente;
  final String activityEmail;
  final String description;
  final String createdAtIso;

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "suggesterUserId": suggesterUserId,
      "activityName": activityName,
      "referente": referente,
      "activityEmail": activityEmail,
      "description": description,
      "createdAtIso": createdAtIso,
    };
  }

  static AffiliateLead? fromJson(Map<String, dynamic> json) {
    final id = (json["id"] ?? "").toString().trim();
    final suggesterUserId = (json["suggesterUserId"] ?? "").toString().trim();
    final activityName = (json["activityName"] ?? "").toString().trim();
    final referente = (json["referente"] ?? "").toString().trim();
    final activityEmail = (json["activityEmail"] ?? "").toString().trim();
    final description = (json["description"] ?? "").toString().trim();
    final createdAtIso = (json["createdAtIso"] ?? "").toString().trim();
    if (id.isEmpty || suggesterUserId.isEmpty || activityName.isEmpty) {
      return null;
    }
    return AffiliateLead(
      id: id,
      suggesterUserId: suggesterUserId,
      activityName: activityName,
      referente: referente,
      activityEmail: activityEmail,
      description: description,
      createdAtIso: createdAtIso,
    );
  }
}

class AffiliateLeadStatus {
  const AffiliateLeadStatus({
    required this.lead,
    required this.isAffiliated,
    required this.isGenerating,
    required this.activityType,
    required this.city,
    required this.matchedRequestId,
  });

  final AffiliateLead lead;
  final bool isAffiliated;
  final bool isGenerating;
  final String activityType;
  final String city;
  final String matchedRequestId;
}

class AffiliateActivityService {
  static const String _storageKey = "affiliate_activity_leads_v1";

  static String _normalize(String value) {
    final lower = value.toLowerCase().trim();
    final allowed = RegExp(r"[a-z0-9]");
    final buffer = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      if (allowed.hasMatch(ch)) buffer.write(ch);
    }
    return buffer.toString();
  }

  static String _emailFromItem(Map<String, dynamic> item) {
    return (item["email"] ?? item["mail"] ?? item["Email"] ?? "")
        .toString()
        .trim();
  }

  static String _nameFromItem(Map<String, dynamic> item) {
    return (item["insegna"] ?? item["activityName"] ?? item["title"] ?? "")
        .toString()
        .trim();
  }

  static String _typeFromItem(Map<String, dynamic> item) {
    return (item["tipo_attivita"] ??
            item["activityType"] ??
            item["typeLabel"] ??
            "")
        .toString()
        .trim();
  }

  static String _cityFromItem(Map<String, dynamic> item) {
    return (item["citta"] ?? item["city"] ?? "").toString().trim();
  }

  static bool _isGeneratingFromItem(Map<String, dynamic> item) {
    final boolKeys = const [
      "isGenerating",
      "is_generating",
      "hasConfirmedPurchases",
      "has_confirmed_purchases",
      "paymentsEnabled",
      "payments_enabled",
    ];
    for (final key in boolKeys) {
      final v = item[key];
      if (v is bool) return v;
      final s = (v ?? "").toString().trim().toLowerCase();
      if (s == "true" || s == "1" || s == "yes" || s == "si") return true;
    }

    final numericKeys = const [
      "confirmedPurchasesCount",
      "confirmed_purchases_count",
      "paymentsConfirmedCount",
      "payments_confirmed_count",
      "incassiCount",
      "incassi_count",
      "totalConfirmedCents",
      "total_confirmed_cents",
    ];
    for (final key in numericKeys) {
      final v = item[key];
      if (v is num && v > 0) return true;
      final n = num.tryParse((v ?? "").toString().trim());
      if (n != null && n > 0) return true;
    }
    return false;
  }

  static Future<List<AffiliateLead>> _loadAllLeads() async {
    await HiveProfile.ensureOpen();
    final raw = HiveProfile.loadField(_storageKey)?.trim() ?? "";
    if (raw.isEmpty) return <AffiliateLead>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <AffiliateLead>[];
      return decoded
          .whereType<Map>()
          .map((e) => AffiliateLead.fromJson(Map<String, dynamic>.from(e)))
          .whereType<AffiliateLead>()
          .toList();
    } catch (_) {
      return <AffiliateLead>[];
    }
  }

  static Future<void> _saveAllLeads(List<AffiliateLead> leads) async {
    final payload = leads.map((e) => e.toJson()).toList();
    await HiveProfile.saveField(_storageKey, jsonEncode(payload));
  }

  static Future<void> addLead({
    required String activityName,
    required String referente,
    required String activityEmail,
    required String description,
  }) async {
    final userId = (AuthState.user?.userId ?? "").trim();
    if (userId.isEmpty) {
      throw Exception("Utente non autenticato.");
    }
    final lead = AffiliateLead(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      suggesterUserId: userId,
      activityName: activityName.trim(),
      referente: referente.trim(),
      activityEmail: activityEmail.trim(),
      description: description.trim(),
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
    );

    final leads = await _loadAllLeads();
    leads.add(lead);
    await _saveAllLeads(leads);
  }

  static Future<List<AffiliateLead>> getMyLeads() async {
    final userId = (AuthState.user?.userId ?? "").trim();
    if (userId.isEmpty) return <AffiliateLead>[];
    final all = await _loadAllLeads();
    final out = all.where((e) => e.suggesterUserId == userId).toList();
    out.sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
    return out;
  }

  static Future<List<AffiliateLeadStatus>> getMyLeadStatuses() async {
    final leads = await getMyLeads();
    if (leads.isEmpty) return <AffiliateLeadStatus>[];

    List<Map<String, dynamic>> approved = <Map<String, dynamic>>[];
    try {
      approved = await ActivityRequestService.fetchApprovedActivitiesPublic();
    } catch (_) {}

    final statuses = <AffiliateLeadStatus>[];
    for (final lead in leads) {
      final leadEmail = _normalize(lead.activityEmail);
      final leadName = _normalize(lead.activityName);

      Map<String, dynamic>? matched;
      for (final item in approved) {
        final itemEmail = _normalize(_emailFromItem(item));
        final itemName = _normalize(_nameFromItem(item));
        final sameEmail = leadEmail.isNotEmpty &&
            itemEmail.isNotEmpty &&
            leadEmail == itemEmail;
        final sameName = leadName.isNotEmpty &&
            itemName.isNotEmpty &&
            (itemName.contains(leadName) || leadName.contains(itemName));
        if (sameEmail || sameName) {
          matched = item;
          break;
        }
      }

      final isAffiliated = matched != null;
      final isGenerating = matched != null && _isGeneratingFromItem(matched);
      final type = matched == null ? "" : _typeFromItem(matched);
      final city = matched == null ? "" : _cityFromItem(matched);
      final requestId =
          (matched?["requestId"] ?? matched?["id"] ?? "").toString().trim();

      statuses.add(
        AffiliateLeadStatus(
          lead: lead,
          isAffiliated: isAffiliated,
          isGenerating: isGenerating,
          activityType: type,
          city: city,
          matchedRequestId: requestId,
        ),
      );
    }
    return statuses;
  }
}
