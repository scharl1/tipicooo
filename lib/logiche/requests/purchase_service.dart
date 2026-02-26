import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/logiche/requests/staff_join_service.dart';
import 'package:tipicooo/logiche/requests/review_service.dart';
import 'package:tipicooo/logiche/config/api_endpoints.dart';

class PurchaseService {
  static const String baseUrl =
      ApiEndpoints.adminBaseUrl;
  static String? _lastCreatePurchaseError;

  static String? get lastCreatePurchaseError => _lastCreatePurchaseError;

  static Future<Map<String, String>> _headers() async {
    final idToken = await AuthService.instance.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception("ID Token non trovato");
    }
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $idToken",
    };
  }

  static const String _pendingCountKeyBase = "purchase_pending_count";
  static const String _pendingIdsKeyBase = "purchase_pending_ids";
  static const String _handledIdsKeyBase = "purchase_handled_ids";
  static const String _handledInitKeyBase = "purchase_handled_init";
  static const String _userPurchaseStatusKeyBase = "purchase_user_status_map";
  static const String _userPurchaseStatusInitKeyBase =
      "purchase_user_status_init";
  static const String _userTrackedPurchaseIdsKeyBase =
      "purchase_user_tracked_ids";
  static const String _reviewReminderStateKeyBase =
      "purchase_review_reminder_state";
  static const Duration _reviewReminderInterval = Duration(hours: 1);
  static const Duration _reviewWindow = Duration(days: 10);
  static const int _maxReviewReminders = 3;
  static Timer? _activityPollTimer;

  static bool _isConfirmedStatus(String status) =>
      status.trim().toLowerCase() == "confirmed";
  static bool _isRejectedStatus(String status) =>
      status.trim().toLowerCase() == "rejected";
  static bool _isTerminalStatus(String status) =>
      _isConfirmedStatus(status) || _isRejectedStatus(status);

  static String _fmtEuroFromCents(num value) {
    final cents = value.toInt();
    final sign = cents < 0 ? "-" : "";
    final abs = cents.abs();
    final euro = abs ~/ 100;
    final cent = abs % 100;
    return "$sign$euro,${cent.toString().padLeft(2, '0')}";
  }

  static String _fmtItalianDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$d/$m/$y alle $hh:$mm";
  }

  static DateTime? _parsePurchaseCreatedAt(Map<String, dynamic> it) {
    final raw =
        (it["createdAt"] ??
                it["created_at"] ??
                it["requestedAt"] ??
                it["requestAt"] ??
                "")
            .toString()
            .trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static DateTime? _parsePurchaseHandledAt(Map<String, dynamic> it) {
    final raw =
        (it["handledAt"] ??
                it["confirmedAt"] ??
                it["rejectedAt"] ??
                it["updatedAt"] ??
                "")
            .toString()
            .trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static String _currentMonthKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    return "$y-$m";
  }

  static void _notifyConfirmed() {
    NotificationController.instance.addNotification(
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: "Pagamento approvato",
        message: "Il tuo pagamento è stato approvato.",
        timestamp: DateTime.now(),
        action: "open_user_cashback",
      ),
    );
  }

  static void _notifyRejected() {
    NotificationController.instance.addNotification(
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: "Pagamento rifiutato",
        message: "Il tuo pagamento è stato rifiutato dall'attività.",
        timestamp: DateTime.now(),
        action: "open_user_cashback",
      ),
    );
  }

  static DateTime? _parseReviewStartAt(Map<String, dynamic> it) {
    final raw =
        (it["confirmedAt"] ??
                it["handledAt"] ??
                it["updatedAt"] ??
                it["createdAt"] ??
                "")
            .toString()
            .trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static int _safeInt(dynamic v, {int fallback = 0}) {
    if (v is num) return v.toInt();
    if (v is String) {
      final n = int.tryParse(v.trim());
      if (n != null) return n;
    }
    return fallback;
  }

  static Future<void> _checkReviewReminders(
    List<Map<String, dynamic>> purchases,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateKey = await _scopedKey(_reviewReminderStateKeyBase);
      final raw = prefs.getString(stateKey) ?? "{}";
      final decoded = jsonDecode(raw);
      final state = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};

      final reviewedIds = await ReviewService.getLocallyReviewedPurchaseIds();
      final now = DateTime.now();
      final activeConfirmedIds = <String>{};

      for (final it in purchases) {
        final purchaseId = (it["purchaseId"] ?? "").toString().trim();
        if (purchaseId.isEmpty) continue;

        final status = (it["status"] ?? "").toString().trim().toLowerCase();
        if (status != "confirmed") continue;
        activeConfirmedIds.add(purchaseId);

        if (reviewedIds.contains(purchaseId)) {
          state.remove(purchaseId);
          continue;
        }

        final startAt = _parseReviewStartAt(it);
        if (startAt == null) continue;
        if (now.difference(startAt) > _reviewWindow) {
          continue;
        }

        final existing = state[purchaseId];
        final entry = existing is Map<String, dynamic>
            ? existing
            : <String, dynamic>{};

        final sent = _safeInt(entry["sent"]);
        if (sent >= _maxReviewReminders) continue;

        DateTime? lastAt;
        final rawLast = (entry["lastAt"] ?? "").toString().trim();
        if (rawLast.isNotEmpty) {
          lastAt = DateTime.tryParse(rawLast)?.toLocal();
        }
        final baseAt = lastAt ?? startAt;
        if (now.difference(baseAt) < _reviewReminderInterval) continue;

        final activityName = (it["activityName"] ??
                it["insegna"] ??
                it["activityTitle"] ??
                "l'attività")
            .toString()
            .trim();

        NotificationController.instance.addNotification(
          AppNotification(
            id: "review_reminder_${purchaseId}_${sent + 1}",
            title: "Lascia una recensione",
            message:
                "Hai completato un pagamento su $activityName. Lascia la recensione (${sent + 1}/$_maxReviewReminders).",
            timestamp: now,
            action: "open_user_cashback",
          ),
        );

        state[purchaseId] = {
          "sent": sent + 1,
          "lastAt": now.toUtc().toIso8601String(),
          "startAt": startAt.toUtc().toIso8601String(),
        };
      }

      final stateKeys = state.keys.map((e) => e.toString()).toList();
      for (final k in stateKeys) {
        if (!activeConfirmedIds.contains(k)) {
          state.remove(k);
        }
      }

      await prefs.setString(stateKey, jsonEncode(state));
    } catch (e) {
      debugPrint("Errore checkReviewReminders: $e");
    }
  }

  static Future<String> _currentUserScope() async {
    try {
      final attrs = await AuthService.instance.getUserAttributes();
      final sub = (attrs["sub"] ?? "").trim();
      if (sub.isNotEmpty) return sub;
    } catch (_) {}
    return "guest";
  }

  static Future<String> _scopedKey(String base) async {
    final scope = await _currentUserScope();
    return "${base}_$scope";
  }

  static int _parseEuroToCents(String raw) {
    final cleaned = raw.trim().replaceAll(" ", "");
    if (cleaned.isEmpty) return 0;
    final normalized = cleaned.replaceAll(",", ".");
    final value = double.tryParse(normalized);
    if (value == null || value.isNaN || value.isInfinite) return 0;
    if (value <= 0) return 0;
    return (value * 100).round();
  }

  static Future<String?> createPurchase({
    required String activityRequestId,
    required String totalEuroText,
  }) async {
    try {
      _lastCreatePurchaseError = null;
      final headers = await _headers();
      final cleanedRequestId = activityRequestId.trim();
      if (cleanedRequestId.isEmpty) {
        _lastCreatePurchaseError = "Attività non valida. Riapri la scheda attività.";
        return null;
      }
      final totalCents = _parseEuroToCents(totalEuroText);
      if (totalCents <= 0) {
        _lastCreatePurchaseError = "Importo non valido.";
        return null;
      }

      final url = Uri.parse("$baseUrl/purchase-create");
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "activityRequestId": cleanedRequestId,
          "totalCents": totalCents,
        }),
      );

      if (response.statusCode != 200) {
        String parsedError = "";
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic>) {
            parsedError =
                (body["error"] ?? body["message"] ?? "").toString().trim();
          }
        } catch (_) {}
        _lastCreatePurchaseError = parsedError.isEmpty
            ? "Errore server (${response.statusCode})."
            : "Errore server (${response.statusCode}): $parsedError";
        debugPrint(
          "purchase-create failed: ${response.statusCode} ${response.body}",
        );
        return null;
      }

      final data = jsonDecode(response.body);
      final id = (data["purchaseId"] ?? "").toString().trim();
      if (id.isEmpty) return null;

      // Track locally the just-sent purchase so we can reliably notify when handled.
      final prefs = await SharedPreferences.getInstance();
      final trackedKey = await _scopedKey(_userTrackedPurchaseIdsKeyBase);
      final trackedRaw = prefs.getString(trackedKey) ?? "[]";
      final tracked = (jsonDecode(trackedRaw) is List)
          ? (jsonDecode(trackedRaw) as List).map((e) => e.toString()).toSet()
          : <String>{};
      tracked.add(id);
      final trackedSorted = tracked.toList()..sort();
      await prefs.setString(trackedKey, jsonEncode(trackedSorted));

      NotificationController.instance.addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: "Pagamento inviato",
          message:
              "La tua richiesta di pagamento è stata inviata all'attività.",
          timestamp: DateTime.now(),
          action: "open_user_cashback",
        ),
      );

      // Re-check ravvicinati per mostrare subito esito approvazione/rifiuto.
      unawaited(
        Future.delayed(const Duration(seconds: 10), () async {
          await checkUserPurchaseUpdates();
        }),
      );
      unawaited(
        Future.delayed(const Duration(seconds: 25), () async {
          await checkUserPurchaseUpdates();
        }),
      );

      return id;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains("ID Token non trovato")) {
        _lastCreatePurchaseError = "Sessione scaduta. Esci e rientra nell'app.";
      } else {
        _lastCreatePurchaseError = "Errore di rete o sessione.";
      }
      debugPrint("Errore createPurchase: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchMySummary() async {
    try {
      final headers = await _headers();
      final url = Uri.parse("$baseUrl/purchase-my-summary");
      final response = await http.get(url, headers: headers);
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Errore fetchMySummary: $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMyPurchases({
    int limit = 20,
  }) async {
    try {
      final headers = await _headers();
      final url = Uri.parse("$baseUrl/purchase-my-list?limit=$limit");
      final response = await http.get(url, headers: headers);
      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      final data = jsonDecode(response.body);
      final items = (data is Map && data["items"] is List)
          ? data["items"] as List
          : <dynamic>[];
      return items
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (e) {
      debugPrint("Errore fetchMyPurchases: $e");
      return <Map<String, dynamic>>[];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPendingForActivity({
    required String activityRequestId,
    int limit = 50,
  }) async {
    try {
      final headers = await _headers();
      final encoded = Uri.encodeComponent(activityRequestId.trim());
      final url = Uri.parse(
        "$baseUrl/purchase-activity-pending?activityRequestId=$encoded&limit=$limit",
      );
      final response = await http.get(url, headers: headers);
      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      final data = jsonDecode(response.body);
      final items = (data is Map && data["items"] is List)
          ? data["items"] as List
          : <dynamic>[];
      return items
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (e) {
      debugPrint("Errore fetchPendingForActivity: $e");
      return <Map<String, dynamic>>[];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMonthOperationsForActivity({
    required String activityRequestId,
    required String monthKey, // YYYY-MM (mese contabile)
    int limit = 200,
  }) async {
    try {
      final headers = await _headers();
      final a = Uri.encodeComponent(activityRequestId.trim());
      final m = Uri.encodeComponent(monthKey.trim());
      final url = Uri.parse(
        "$baseUrl/purchase-activity-month?activityRequestId=$a&month=$m&limit=$limit",
      );
      final response = await http.get(url, headers: headers);
      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      final data = jsonDecode(response.body);
      final items = (data is Map && data["items"] is List)
          ? data["items"] as List
          : <dynamic>[];
      return items
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (e) {
      debugPrint("Errore fetchMonthOperationsForActivity: $e");
      return <Map<String, dynamic>>[];
    }
  }

  static Future<bool> confirmPurchase({required String purchaseId}) async {
    try {
      final headers = await _headers();
      final url = Uri.parse("$baseUrl/purchase-confirm");
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"purchaseId": purchaseId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Errore confirmPurchase: $e");
      return false;
    }
  }

  static Future<bool> rejectPurchase({
    required String purchaseId,
    required String rejectionCode,
    String rejectionNote = "",
  }) async {
    try {
      final headers = await _headers();
      final url = Uri.parse("$baseUrl/purchase-reject");
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "purchaseId": purchaseId,
          "rejectionCode": rejectionCode,
          "rejectionNote": rejectionNote,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Errore rejectPurchase: $e");
      return false;
    }
  }

  static Future<void> checkActivityPendingPurchases() async {
    try {
      await StaffJoinService.checkOwnerPendingRequests();
      await StaffJoinService.checkMyIncomingInvites();
      await StaffJoinService.checkMyStaffApprovals();

      final activities = await ActivityRequestService.fetchActivitiesForMe();
      final approved = activities.where((it) {
        final status = (it["status"] ?? "").toString();
        return status == "approved";
      }).toList();

      if (approved.isEmpty) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final baseKey = await _scopedKey(_pendingCountKeyBase);
      final baseIdsKey = await _scopedKey(_pendingIdsKeyBase);
      final handledBaseKey = await _scopedKey(_handledIdsKeyBase);
      final handledInitBase = await _scopedKey(_handledInitKeyBase);
      final monthKey = _currentMonthKey();

      for (final a in approved) {
        final requestId = (a["requestId"] ?? "").toString().trim();
        if (requestId.isEmpty) continue;
        final insegna = (a["insegna"] ?? "Attività").toString().trim();

        final pending = await fetchPendingForActivity(
          activityRequestId: requestId,
          limit: 50,
        );
        final count = pending.length;
        final currentIds = pending
            .map((it) => (it["purchaseId"] ?? "").toString().trim())
            .where((id) => id.isNotEmpty)
            .toSet();

        final idsKey = "${baseIdsKey}_$requestId";
        final lastIdsRaw = prefs.getString(idsKey) ?? "";
        final lastIds = lastIdsRaw
            .split("|")
            .map((it) => it.trim())
            .where((it) => it.isNotEmpty)
            .toSet();
        final hasNewPending = currentIds.any((id) => !lastIds.contains(id));

        final key = "${baseKey}_$requestId";
        final lastCount = prefs.getInt(key) ?? 0;
        if (hasNewPending || (count > lastCount && currentIds.isNotEmpty)) {
          final newPending = pending.where((it) {
            final id = (it["purchaseId"] ?? "").toString().trim();
            return id.isNotEmpty && !lastIds.contains(id);
          }).toList();

          Map<String, dynamic>? latest;
          if (newPending.isNotEmpty) {
            newPending.sort((a, b) {
              final ad = _parsePurchaseCreatedAt(a);
              final bd = _parsePurchaseCreatedAt(b);
              if (ad == null && bd == null) return 0;
              if (ad == null) return -1;
              if (bd == null) return 1;
              return ad.compareTo(bd);
            });
            latest = newPending.last;
          }

          final totalCents = (latest?["totalCents"] ?? 0) as num;
          final when = latest != null ? _parsePurchaseCreatedAt(latest) : null;
          final whenLabel = when != null
              ? _fmtItalianDateTime(when)
              : _fmtItalianDateTime(DateTime.now());
          final amountLabel = _fmtEuroFromCents(totalCents);
          final detailedMessage = latest != null
              ? "$insegna: pagamento di € $amountLabel effettuato il $whenLabel."
              : "$insegna: hai $count richieste di pagamento in attesa.";

          NotificationController.instance.addNotification(
            AppNotification(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: "Nuovo pagamento da confermare",
              message: detailedMessage,
              timestamp: DateTime.now(),
              action: "open_activity_payments|$requestId",
            ),
          );
        }
        await prefs.setInt(key, count);
        final sortedIds = currentIds.toList()..sort();
        await prefs.setString(idsKey, sortedIds.join("|"));

        // Notifiche su operazioni già gestite (conferma/rifiuto), incluse
        // quelle fatte da eventuali dipendenti.
        final ops = await fetchMonthOperationsForActivity(
          activityRequestId: requestId,
          monthKey: monthKey,
          limit: 300,
        );
        final handledOps = ops.where((op) {
          final s = (op["status"] ?? "").toString().trim().toLowerCase();
          return s == "confirmed" || s == "rejected";
        }).toList();

        final handledTokens = handledOps.map((op) {
          final pid = (op["purchaseId"] ?? "").toString().trim();
          final s = (op["status"] ?? "").toString().trim().toLowerCase();
          final h = (op["handledAt"] ??
                  op["confirmedAt"] ??
                  op["rejectedAt"] ??
                  op["updatedAt"] ??
                  "")
              .toString()
              .trim();
          return "$pid|$s|$h";
        }).where((t) => t.isNotEmpty && !t.startsWith("|")).toSet();

        final handledKey = "${handledBaseKey}_${requestId}_$monthKey";
        final handledInitKey = "${handledInitBase}_${requestId}_$monthKey";
        final handledInitialized = prefs.getBool(handledInitKey) ?? false;
        final handledRaw = prefs.getString(handledKey) ?? "";
        final handledLast = handledRaw
            .split("||")
            .map((x) => x.trim())
            .where((x) => x.isNotEmpty)
            .toSet();

        if (handledInitialized) {
          final newHandled = handledOps.where((op) {
            final pid = (op["purchaseId"] ?? "").toString().trim();
            final s = (op["status"] ?? "").toString().trim().toLowerCase();
            final h = (op["handledAt"] ??
                    op["confirmedAt"] ??
                    op["rejectedAt"] ??
                    op["updatedAt"] ??
                    "")
                .toString()
                .trim();
            final token = "$pid|$s|$h";
            return pid.isNotEmpty && !handledLast.contains(token);
          }).toList();

          for (final op in newHandled) {
            final s = (op["status"] ?? "").toString().trim().toLowerCase();
            final totalCents = (op["totalCents"] is num)
                ? (op["totalCents"] as num).toInt()
                : 0;
            final amountLabel = _fmtEuroFromCents(totalCents);
            final when =
                _parsePurchaseHandledAt(op) ??
                _parsePurchaseCreatedAt(op) ??
                DateTime.now();
            final whenLabel = _fmtItalianDateTime(when);
            final handledByName = (op["handledByName"] ?? "")
                .toString()
                .trim();
            final handledByEmail = (op["handledByEmail"] ?? "")
                .toString()
                .trim();
            final actor = handledByName.isNotEmpty
                ? handledByName
                : (handledByEmail.isNotEmpty ? handledByEmail : "gestore");
            final rejectionCode = (op["rejectionCode"] ?? "").toString().trim();

            final msg = s == "confirmed"
                ? "$insegna: pagamento di € $amountLabel confermato il $whenLabel da $actor."
                : (rejectionCode.isEmpty
                      ? "$insegna: pagamento di € $amountLabel rifiutato il $whenLabel da $actor."
                      : "$insegna: pagamento di € $amountLabel rifiutato il $whenLabel da $actor. Motivo: $rejectionCode.");

            NotificationController.instance.addNotification(
              AppNotification(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: s == "confirmed"
                    ? "Pagamento confermato"
                    : "Pagamento rifiutato",
                message: msg,
                timestamp: DateTime.now(),
                action: "open_activity_payments|$requestId",
              ),
            );
          }
        }

        final handledSorted = handledTokens.toList()..sort();
        await prefs.setString(handledKey, handledSorted.join("||"));
        await prefs.setBool(handledInitKey, true);
      }
    } catch (e) {
      debugPrint("Errore checkActivityPendingPurchases: $e");
    }
  }

  static Future<void> checkUserPurchaseUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshotKey = await _scopedKey(_userPurchaseStatusKeyBase);
      final initKey = await _scopedKey(_userPurchaseStatusInitKeyBase);
      final trackedKey = await _scopedKey(_userTrackedPurchaseIdsKeyBase);

      final currentPurchases = await fetchMyPurchases(limit: 100);
      final currentMap = <String, String>{};
      for (final it in currentPurchases) {
        final purchaseId = (it["purchaseId"] ?? "").toString().trim();
        if (purchaseId.isEmpty) continue;
        final status = (it["status"] ?? "").toString().trim();
        if (status.isEmpty) continue;
        currentMap[purchaseId] = status;
      }

      final initialized = prefs.getBool(initKey) ?? false;
      final lastRaw = prefs.getString(snapshotKey) ?? "{}";
      final Map<String, dynamic> lastDynamic =
          jsonDecode(lastRaw) is Map<String, dynamic>
          ? jsonDecode(lastRaw) as Map<String, dynamic>
          : <String, dynamic>{};
      final lastMap = lastDynamic.map((k, v) => MapEntry(k, v.toString()));
      final trackedRaw = prefs.getString(trackedKey) ?? "[]";
      final trackedIds = (jsonDecode(trackedRaw) is List)
          ? (jsonDecode(trackedRaw) as List).map((e) => e.toString()).toSet()
          : <String>{};

      if (initialized) {
        final notifiedNow = <String>{};
        for (final entry in currentMap.entries) {
          final purchaseId = entry.key;
          final status = entry.value;
          final prev = (lastMap[purchaseId] ?? "").trim();
          if (prev.isEmpty || prev == status) continue;
          // Qualsiasi transizione verso stato finale deve notificare.
          if (!_isTerminalStatus(prev) && _isTerminalStatus(status)) {
            if (_isConfirmedStatus(status)) {
              _notifyConfirmed();
            } else if (_isRejectedStatus(status)) {
              _notifyRejected();
            }
            notifiedNow.add(purchaseId);
          }
        }

        // Strong guarantee for user-originated purchases: if a tracked purchase is
        // now confirmed/rejected, notify even when a transition was missed.
        final toRemove = <String>{};
        for (final purchaseId in trackedIds) {
          final status = (currentMap[purchaseId] ?? "").trim();
          if (!_isTerminalStatus(status)) continue;
          if (notifiedNow.contains(purchaseId)) {
            toRemove.add(purchaseId);
            continue;
          }
          if (_isConfirmedStatus(status)) {
            _notifyConfirmed();
            toRemove.add(purchaseId);
          } else if (_isRejectedStatus(status)) {
            _notifyRejected();
            toRemove.add(purchaseId);
          }
        }
        if (toRemove.isNotEmpty) {
          trackedIds.removeAll(toRemove);
        }
      }

      await prefs.setString(snapshotKey, jsonEncode(currentMap));
      await prefs.setBool(initKey, true);
      final trackedSorted = trackedIds.toList()..sort();
      await prefs.setString(trackedKey, jsonEncode(trackedSorted));
      await _checkReviewReminders(currentPurchases);
    } catch (e) {
      debugPrint("Errore checkUserPurchaseUpdates: $e");
    }
  }

  static Future<void> startActivityPolling() async {
    if (_activityPollTimer != null) return;
    await checkActivityPendingPurchases();
    await checkUserPurchaseUpdates();
    _activityPollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await checkActivityPendingPurchases();
      await checkUserPurchaseUpdates();
    });
  }

  static void stopActivityPolling() {
    _activityPollTimer?.cancel();
    _activityPollTimer = null;
  }
}
