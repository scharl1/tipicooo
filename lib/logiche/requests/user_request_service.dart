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
import 'package:tipicooo/logiche/config/api_endpoints.dart';

class UserRequestService {
  static const String baseUrl =
      ApiEndpoints.adminBaseUrl;
  static const String _pendingKeyBase = "office_request_pending";
  static const String _lastRequestedKeyBase = "office_request_last_requested";
  static const String _approvedNotifiedKeyBase =
      "office_request_approved_notified";
  static const String _pendingNotifiedKeyBase =
      "office_request_pending_notified";
  static const String _adminPendingCountKeyBase = "admin_pending_count";
  static const String _adminNewUsersLastSkKeyBase = "admin_new_users_last_sk";
  static Timer? _adminPollTimer;

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

  // ⭐ INVIO RICHIESTA ACCESSO
  static Future<bool> sendAccessRequest() async {
    try {
      // Recuperiamo l'ID utente da Cognito
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;
      final currentUser = await Amplify.Auth.getCurrentUser();
      final userId = currentUser.userId;

      final url = Uri.parse("$baseUrl/admin-request");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({"userId": userId}),
      );

      debugPrint("STATUS: ${response.statusCode}");
      debugPrint("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        final pendingKey = await _scopedKey(_pendingKeyBase);
        final lastRequestedKey = await _scopedKey(_lastRequestedKeyBase);
        final approvedNotifiedKey = await _scopedKey(_approvedNotifiedKeyBase);
        final pendingNotifiedKey = await _scopedKey(_pendingNotifiedKeyBase);
        await prefs.setBool(pendingKey, true);
        await prefs.setBool(lastRequestedKey, true);
        await prefs.setBool(approvedNotifiedKey, false);
        await prefs.setBool(pendingNotifiedKey, false);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("Errore invio richiesta: $e");
      return false;
    }
  }

  // ⭐ RECUPERO STATO UTENTE (abilitato / richiesta inviata)
  static Future<Map<String, dynamic>> getUserStatus() async {
    try {
      // Recuperiamo l'ID Token Cognito VERO
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final url = Uri.parse("$baseUrl/admin-request/status");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
      );

      debugPrint("STATUS (getUserStatus): ${response.statusCode}");
      debugPrint("BODY (getUserStatus): ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _syncLocalRequestStatus(
          requested: data["requested"] == true,
          enabled: data["enabled"] == true,
        );
        return data;
      }

      if (response.statusCode == 404) {
        await _syncLocalRequestStatus(requested: false, enabled: false);
        return {"enabled": false, "requested": false};
      }

      throw Exception("Errore status utente: ${response.statusCode}");
    } catch (e) {
      debugPrint("Errore getUserStatus: $e");

      return {"enabled": false, "requested": false};
    }
  }

  // ⭐ ANNULLA RICHIESTA (cancella tutte le richieste dell'utente)
  static Future<bool> deleteUserRequests() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final response = await http.post(
        Uri.parse("$baseUrl/user-delete-requests"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        final pendingKey = await _scopedKey(_pendingKeyBase);
        final lastRequestedKey = await _scopedKey(_lastRequestedKeyBase);
        final approvedNotifiedKey = await _scopedKey(_approvedNotifiedKeyBase);
        await prefs.setBool(pendingKey, false);
        await prefs.setBool(lastRequestedKey, false);
        await prefs.setBool(approvedNotifiedKey, false);
        return true;
      }
    } catch (e) {
      debugPrint("Errore deleteUserRequests: $e");
    }

    return false;
  }

  static Future<void> _syncLocalRequestStatus({
    required bool requested,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingKey = await _scopedKey(_pendingKeyBase);
    final lastRequestedKey = await _scopedKey(_lastRequestedKeyBase);
    final approvedNotifiedKey = await _scopedKey(_approvedNotifiedKeyBase);
    final pendingNotifiedKey = await _scopedKey(_pendingNotifiedKeyBase);
    final pending = prefs.getBool(pendingKey) ?? false;
    final lastRequested = prefs.getBool(lastRequestedKey) ?? false;
    final approvedByStatus = enabled;
    // accesso ufficio: consentito solo quando backend restituisce enabled=true

    if (approvedByStatus) {
      final approvedNotified = prefs.getBool(approvedNotifiedKey) ?? false;
      if (!approvedNotified) {
        NotificationController.instance.addNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: "Richiesta approvata",
            message:
                "La tua richiesta è stata approvata, puoi accedere all'ufficio.",
            timestamp: DateTime.now(),
          ),
        );
        await prefs.setBool(approvedNotifiedKey, true);
      }
      await prefs.setBool(pendingKey, false);
      await prefs.setBool(lastRequestedKey, false);
      await prefs.setBool(pendingNotifiedKey, false);
      return;
    }

    if (requested && !pending) {
      await prefs.setBool(pendingKey, true);
      await prefs.setBool(lastRequestedKey, true);
      await prefs.setBool(approvedNotifiedKey, false);
      final pendingNotified = prefs.getBool(pendingNotifiedKey) ?? false;
      if (!pendingNotified) {
        NotificationController.instance.addNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: "Richiesta in attesa",
            message: "La tua richiesta è in attesa di approvazione.",
            timestamp: DateTime.now(),
          ),
        );
        await prefs.setBool(pendingNotifiedKey, true);
      }
      return;
    }

    if (!requested && (pending || lastRequested)) {
      NotificationController.instance.addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: "Richiesta rifiutata",
          message: "La richiesta è stata rifiutata.",
          timestamp: DateTime.now(),
        ),
      );
      await prefs.setBool(pendingKey, false);
      await prefs.setBool(lastRequestedKey, false);
      await prefs.setBool(approvedNotifiedKey, false);
      await prefs.setBool(pendingNotifiedKey, false);
    }
  }

  // ⭐ NOTIFICA ADMIN: richieste pendenti
  static Future<void> checkAdminPendingRequests() async {
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
        Uri.parse("$baseUrl/admin-list-requests"),
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

      final prefs = await SharedPreferences.getInstance();
      final adminPendingCountKey = await _scopedKey(_adminPendingCountKeyBase);
      final lastCount = prefs.getInt(adminPendingCountKey) ?? 0;

      if (count != lastCount) {
        final isIncrease = count > lastCount;
        final title = isIncrease ? "Nuove richieste" : "Richieste aggiornate";
        final message = isIncrease
            ? "Hai $count richieste in attesa di approvazione."
            : "Ora hai $count richieste in attesa di approvazione.";

        NotificationController.instance.addNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            message: message,
            timestamp: DateTime.now(),
            action: "open_office_admin_requests",
          ),
        );
      }

      await prefs.setInt(adminPendingCountKey, count);
    } catch (e) {
      debugPrint("Errore checkAdminPendingRequests: $e");
    }
  }

  // ⭐ NOTIFICA ADMIN: nuovi utenti iscritti
  static Future<void> checkAdminNewUsers() async {
    try {
      final isAdmin = await AuthService.instance.isAdmin();
      if (!isAdmin) {
        _stopAdminPolling();
        return;
      }

      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final prefs = await SharedPreferences.getInstance();
      final lastSkKey = await _scopedKey(_adminNewUsersLastSkKeyBase);
      final lastSk = (prefs.getString(lastSkKey) ?? "").trim();

      final uri = lastSk.isEmpty
          ? Uri.parse("$baseUrl/admin-new-users-count")
          : Uri.parse(
              "$baseUrl/admin-new-users-count?sinceSk=${Uri.encodeComponent(lastSk)}",
            );

      final response = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        _stopAdminPolling();
        return;
      }
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final latestSk = (data["latestSk"] ?? "").toString().trim();
      final newCount = (data["newCount"] is num)
          ? (data["newCount"] as num).toInt()
          : 0;

      // Primo run: settiamo il cursore senza notificare.
      if (lastSk.isEmpty) {
        if (latestSk.isNotEmpty) {
          await prefs.setString(lastSkKey, latestSk);
        }
        return;
      }

      if (newCount > 0) {
        NotificationController.instance.addNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: "Nuovo utente iscritto",
            message: newCount == 1
                ? "C'è 1 nuovo utente iscritto."
                : "Ci sono $newCount nuovi utenti iscritti.",
            timestamp: DateTime.now(),
            action: "open_office_users",
          ),
        );
      }

      if (latestSk.isNotEmpty) {
        await prefs.setString(lastSkKey, latestSk);
      }
    } catch (e) {
      debugPrint("Errore checkAdminNewUsers: $e");
    }
  }

  static Future<void> startAdminPolling() async {
    if (_adminPollTimer != null) return;

    final isAdmin = await AuthService.instance.isAdmin();
    if (!isAdmin) {
      _stopAdminPolling();
      return;
    }

    await checkAdminPendingRequests();
    await checkAdminNewUsers();

    _adminPollTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      await checkAdminPendingRequests();
      await checkAdminNewUsers();
    });
  }

  static void stopAdminPolling() {
    _stopAdminPolling();
  }

  static void _stopAdminPolling() {
    _adminPollTimer?.cancel();
    _adminPollTimer = null;
  }

  static Future<void> resetAdminPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final adminPendingCountKey = await _scopedKey(_adminPendingCountKeyBase);
    await prefs.setInt(adminPendingCountKey, 0);
  }

  static Future<void> _resetAdminPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final adminPendingCountKey = await _scopedKey(_adminPendingCountKeyBase);
    await prefs.setInt(adminPendingCountKey, 0);
  }
}
