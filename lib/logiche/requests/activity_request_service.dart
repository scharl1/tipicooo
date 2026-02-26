import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/logiche/requests/activity_photos_service.dart';

class ActivityRequestService {
  static const String baseUrl =
      "https://efs0gx9nm4.execute-api.eu-south-1.amazonaws.com/prod";
  static const String _officeGatewayBaseUrl =
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod";
  static const String _activityStatusKeyBase = "activity_request_last_status";
  static const String _activityApprovedNotifiedKeyBase =
      "activity_request_approved_notified";
  static const String _adminActivityPendingCountKeyBase =
      "admin_activity_pending_count";
  static const String _adminActivityPendingIdsKeyBase =
      "admin_activity_pending_ids";
  static Timer? _adminActivityPollTimer;
  static bool _activityStatusEndpointMissing = false;

  static bool _isActivityPublishReady(Map<String, dynamic> item) {
    final logo = (item["logo"] ?? item["logoKey"] ?? "").toString().trim();
    if (logo.isEmpty) return false;
    final rawPhotoKeys = item["photoKeys"];
    if (rawPhotoKeys is List) {
      final count = rawPhotoKeys
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .length;
      return count >= 5;
    }
    return false;
  }

  static Future<String> _currentUserScope() async {
    try {
      final currentUser = await Amplify.Auth.getCurrentUser();
      final userId = currentUser.userId.trim();
      if (userId.isNotEmpty) return userId;
    } catch (_) {}
    return "guest";
  }

  static Future<String> _scopedKey(String base) async {
    final scope = await _currentUserScope();
    return "${base}_$scope";
  }

  static Future<String?> sendActivityRequest(
    Map<String, dynamic> payload,
  ) async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final response = await http.post(
        Uri.parse("$baseUrl/activity-request"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode(payload),
      );

      debugPrint("STATUS (activity-request): ${response.statusCode}");
      debugPrint("BODY (activity-request): ${response.body}");

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final requestId = data["requestId"];
      if (requestId is String && requestId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final approvedNotifiedKey = await _scopedKey(
          _activityApprovedNotifiedKeyBase,
        );
        final statusKey = await _scopedKey(_activityStatusKeyBase);
        await prefs.setBool(approvedNotifiedKey, false);
        await prefs.setString(statusKey, "pending");
        return requestId;
      }
      return null;
    } catch (e) {
      debugPrint("Errore invio activity-request: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchLatestStatus() async {
    try {
      if (_activityStatusEndpointMissing) {
        return _fetchLatestStatusFallback();
      }
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final response = await http
          .get(
            Uri.parse("$baseUrl/activity-request-status"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $idToken",
            },
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 404) {
        _activityStatusEndpointMissing = true;
        debugPrint(
          "Endpoint activity-request-status non trovato (404). Disabilito ulteriori richieste.",
        );
        return _fetchLatestStatusFallback();
      }
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final status = (data["status"] ?? "").toString();
      final requestId = (data["requestId"] ?? "").toString();
      await _handleStatusNotification(status: status, requestId: requestId);
      return {"status": status, "requestId": requestId};
    } catch (e) {
      debugPrint("Errore checkLatestStatus: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _fetchLatestStatusFallback() async {
    try {
      final items = await fetchUserActivities();
      if (items.isEmpty) return null;

      items.sort((a, b) {
        final aDate = (a["updatedAt"] ?? a["createdAt"] ?? "")
            .toString()
            .trim();
        final bDate = (b["updatedAt"] ?? b["createdAt"] ?? "")
            .toString()
            .trim();
        return bDate.compareTo(aDate);
      });

      final latest = items.first;
      final status = (latest["status"] ?? "").toString();
      final requestId = (latest["requestId"] ?? "").toString();
      if (status.isEmpty || requestId.isEmpty) return null;

      await _handleStatusNotification(status: status, requestId: requestId);
      return {"status": status, "requestId": requestId};
    } catch (e) {
      debugPrint("Errore _fetchLatestStatusFallback: $e");
      return null;
    }
  }

  static Future<void> _handleStatusNotification({
    required String status,
    required String requestId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final statusKey = await _scopedKey(_activityStatusKeyBase);
    final approvedNotifiedKey = await _scopedKey(
      _activityApprovedNotifiedKeyBase,
    );
    final lastStatus = prefs.getString(statusKey);

    if (status == "approved") {
      bool minPhotosReached = false;
      if (requestId.isNotEmpty) {
        final detail = await fetchRequestDetail(requestId);
        if (detail != null) {
          minPhotosReached = _isActivityPublishReady(detail);
        }
      }

      final alreadyNotified = prefs.getBool(approvedNotifiedKey) ?? false;
      if (minPhotosReached) {
        NotificationController.instance.deleteNotificationsByAction(
          "open_activity_photos",
        );
        await prefs.setBool(approvedNotifiedKey, true);
      } else if (!alreadyNotified || lastStatus != "approved") {
        NotificationController.instance.addNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: "Attività approvata",
            message:
                "Grazie da Tipic.ooo per aver registrato la tua attività! Per renderla visibile carica il logo e almeno 5 foto (fino a 10).",
            timestamp: DateTime.now(),
            action: "open_activity_photos",
          ),
        );
        await prefs.setBool(approvedNotifiedKey, true);
      }
    }
    if (status == "rejected" && lastStatus != "rejected") {
      NotificationController.instance.addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: "Attività non approvata",
          message:
              "L'attività non è stata approvata, per maggiori inforamzioni invii una mail a info@pippo.it Grazie",
          timestamp: DateTime.now(),
          action: "open_register_activity",
        ),
      );
    }

    await prefs.setString(statusKey, status);
  }

  static Future<void> checkLatestStatus() async {
    await fetchLatestStatus();
  }

  static Future<void> checkAdminPendingActivities() async {
    try {
      final isAdmin = await AuthService.instance.isAdmin();
      if (!isAdmin) {
        _stopAdminPolling();
        return;
      }

      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final response = await http.get(
        Uri.parse("$baseUrl/activity-requests?status=pending"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        await _resetAdminPendingCount();
        _stopAdminPolling();
        return;
      }
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final items = (data["items"] is List)
          ? data["items"] as List
          : <dynamic>[];
      final count = items.length;
      final currentIds = items
          .whereType<Map>()
          .map((it) => (it["requestId"] ?? "").toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      final prefs = await SharedPreferences.getInstance();
      final adminActivityPendingCountKey = await _scopedKey(
        _adminActivityPendingCountKeyBase,
      );
      final adminActivityPendingIdsKey = await _scopedKey(
        _adminActivityPendingIdsKeyBase,
      );
      final lastCount = prefs.getInt(adminActivityPendingCountKey) ?? 0;
      final lastIdsRaw = prefs.getString(adminActivityPendingIdsKey) ?? "";
      final lastIds = lastIdsRaw
          .split("|")
          .map((it) => it.trim())
          .where((it) => it.isNotEmpty)
          .toSet();
      final hasNewPending = currentIds.any((id) => !lastIds.contains(id));

      if (hasNewPending || count != lastCount) {
        final isIncrease = count > lastCount;
        final title = isIncrease ? "Nuove attività" : "Attività aggiornate";
        final message = isIncrease
            ? "Hai $count attività in attesa di approvazione."
            : "Ora hai $count attività in attesa di approvazione.";

        NotificationController.instance.addNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            message: message,
            timestamp: DateTime.now(),
            action: "open_office_activity_requests",
          ),
        );
      }

      await prefs.setInt(adminActivityPendingCountKey, count);
      final sortedIds = currentIds.toList()..sort();
      await prefs.setString(adminActivityPendingIdsKey, sortedIds.join("|"));
    } catch (e) {
      debugPrint("Errore checkAdminPendingActivities: $e");
    }
  }

  static Future<void> startAdminPolling() async {
    if (_adminActivityPollTimer != null) return;

    final isAdmin = await AuthService.instance.isAdmin();
    if (!isAdmin) {
      _stopAdminPolling();
      return;
    }

    await checkAdminPendingActivities();
    _adminActivityPollTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => checkAdminPendingActivities(),
    );
  }

  static void stopAdminPolling() {
    _stopAdminPolling();
  }

  static void _stopAdminPolling() {
    _adminActivityPollTimer?.cancel();
    _adminActivityPollTimer = null;
  }

  static Future<void> resetAdminPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final adminActivityPendingCountKey = await _scopedKey(
      _adminActivityPendingCountKeyBase,
    );
    final adminActivityPendingIdsKey = await _scopedKey(
      _adminActivityPendingIdsKeyBase,
    );
    await prefs.setInt(adminActivityPendingCountKey, 0);
    await prefs.setString(adminActivityPendingIdsKey, "");
  }

  static Future<void> _resetAdminPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final adminActivityPendingCountKey = await _scopedKey(
      _adminActivityPendingCountKeyBase,
    );
    final adminActivityPendingIdsKey = await _scopedKey(
      _adminActivityPendingIdsKeyBase,
    );
    await prefs.setInt(adminActivityPendingCountKey, 0);
    await prefs.setString(adminActivityPendingIdsKey, "");
  }

  static Future<bool> deleteActivityRequest(String requestId) async {
    try {
      // Prima elimina tutte le foto/logo associate, poi il record attività.
      final detail = await fetchRequestDetail(requestId);
      if (detail != null) {
        final keysToDelete = <String>{};

        final logo = (detail["logo"] ?? "").toString().trim();
        if (logo.isNotEmpty) keysToDelete.add(logo);

        final rawPhotoKeys = detail["photoKeys"];
        if (rawPhotoKeys is List) {
          for (final item in rawPhotoKeys) {
            final key = item.toString().trim();
            if (key.isNotEmpty) keysToDelete.add(key);
          }
        }

        for (final key in keysToDelete) {
          final ok = await ActivityPhotosService.deletePhoto(
            requestId: requestId,
            key: key,
          );
          if (!ok) {
            // Non bloccare l'eliminazione attività se una foto non è più presente
            // o se il delete foto fallisce: proviamo comunque il delete del record.
            debugPrint(
              "Errore delete foto prima della delete attività (continuo): $key",
            );
          }
        }
      }

      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final response = await http.post(
        Uri.parse("$baseUrl/activity-request-delete"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({"requestId": requestId}),
      );
      debugPrint("STATUS (activity-request-delete): ${response.statusCode}");
      debugPrint("BODY (activity-request-delete): ${response.body}");
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Errore deleteActivityRequest: $e");
      return false;
    }
  }

  static Future<bool> saveActivityPhotos({
    required String requestId,
    required String? logoKey,
    required List<String> photoKeys,
    String? description,
    Map<String, dynamic>? logistics,
  }) async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final payload = <String, dynamic>{
        "requestId": requestId,
        "logo": logoKey,
        "photoKeys": photoKeys,
      };
      final trimmedDescription = description?.trim() ?? "";
      if (trimmedDescription.isNotEmpty) {
        payload["descrizione"] = trimmedDescription;
      }
      if (logistics != null && logistics.isNotEmpty) {
        payload.addAll(logistics);
      }

      final response = await http.post(
        Uri.parse("$baseUrl/activity-photos-save"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode(payload),
      );

      debugPrint("STATUS (activity-photos-save): ${response.statusCode}");
      debugPrint("BODY (activity-photos-save): ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Errore saveActivityPhotos: $e");
      return false;
    }
  }

  static Future<String?> fetchPhotoUrl({
    required String requestId,
    required String key,
  }) async {
    try {
      // Web: evitare header "Authorization" per ridurre i preflight CORS e
      // rendere compatibile il caricamento immagini pubbliche.
      // L'endpoint `activity-photo-get` deve poter restituire URL firmati anche
      // senza autenticazione per le schede visibili ai non loggati.
      final headers = <String, String>{};
      if (!kIsWeb) {
        try {
          final session =
              await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
          final idToken = session.userPoolTokensResult.value.idToken.raw;
          if (idToken.isNotEmpty) {
            headers["Authorization"] = "Bearer $idToken";
          }
        } catch (e) {
          debugPrint("fetchPhotoUrl: impossibile leggere ID token: $e");
        }
      }

      final encodedKey = Uri.encodeComponent(key);
      final candidates = <Uri>[
        // NOTE: su web serve CORS valido. L'endpoint foto e' sul gateway efs0 (baseUrl).
        Uri.parse(
          "$baseUrl/activity-photo-get?requestId=$requestId&key=$encodedKey",
        ),
      ];

      for (final uri in candidates) {
        try {
          // IMPORTANT: su Web non aggiungiamo header custom per evitare preflight CORS.
          // (Cache-Control/Pragma/Authorization non sono "safelisted".)
          final Map<String, String>? requestHeaders = kIsWeb
              ? null
              : {
                  ...headers,
                  "Cache-Control": "no-cache",
                  "Pragma": "no-cache",
                };
          final response = await http.get(uri, headers: requestHeaders);
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final url = data["url"]?.toString();
            if (url != null && url.isNotEmpty) return url;
          } else {
            debugPrint(
              "fetchPhotoUrl non disponibile su ${uri.host} (${response.statusCode})",
            );
          }
        } catch (e) {
          debugPrint("fetchPhotoUrl errore su ${uri.host}: $e");
        }
      }
      return null;
    } catch (e) {
      debugPrint("Errore fetchPhotoUrl: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchRequestDetail(
    String requestId,
  ) async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final response = await http.get(
        Uri.parse("$baseUrl/activity-request-detail?requestId=$requestId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
      );

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      return (data["item"] is Map)
          ? Map<String, dynamic>.from(data["item"])
          : null;
    } catch (e) {
      debugPrint("Errore fetchRequestDetail: $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchUserActivities() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final response = await http.get(
        Uri.parse("$baseUrl/activity-requests-by-user"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
      );

      debugPrint("STATUS (activity-requests-by-user): ${response.statusCode}");
      debugPrint("BODY (activity-requests-by-user): ${response.body}");
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final items = data["items"];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("Errore fetchUserActivities: $e");
      return [];
    }
  }

  /// Attività accessibili dall'utente loggato:
  /// - owner (userId == sub)
  /// - staff (staffUserIds contiene sub)
  ///
  /// Usata per: accettazione pagamenti e notifiche incasso.
  static Future<List<Map<String, dynamic>>> fetchActivitiesForMe() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final response = await http.get(
        Uri.parse("$_officeGatewayBaseUrl/activity-requests-for-me"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final items = data["items"];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("Errore fetchActivitiesForMe: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchApprovedActivities() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final response = await http.get(
        Uri.parse("$baseUrl/activity-requests?status=approved"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
          "Cache-Control": "no-cache",
          "Pragma": "no-cache",
        },
      );

      debugPrint("STATUS (activity-requests approved): ${response.statusCode}");
      debugPrint("BODY (activity-requests approved): ${response.body}");
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final items = data["items"];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where(_isActivityPublishReady)
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("Errore fetchApprovedActivities: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>>
  fetchApprovedActivitiesPublic() async {
    List<Map<String, dynamic>> parseItems(http.Response response) {
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final rawItems = data is Map ? data["items"] : data;
      if (rawItems is! List) return [];

      return rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where(_isActivityPublishReady)
          .toList();
    }

    try {
      final mapPublicResponse = await http
          .get(Uri.parse("$baseUrl/activity-map-public"))
          .timeout(const Duration(seconds: 8));

      return parseItems(mapPublicResponse);
    } catch (e) {
      debugPrint("Errore fetchApprovedActivitiesPublic: $e");
      return [];
    }
  }
}
