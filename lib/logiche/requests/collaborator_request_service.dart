import 'dart:convert';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/config/api_endpoints.dart';

class CollaboratorRequestService {
  static const String baseUrl =
      ApiEndpoints.adminBaseUrl;
  static const String _pendingKeyBase = "collaborator_request_pending";
  static const String _lastRequestedKeyBase =
      "collaborator_request_last_requested";
  static const String _approvedNotifiedKeyBase =
      "collaborator_request_approved_notified";
  static const String _pendingNotifiedKeyBase =
      "collaborator_request_pending_notified";

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

  static Future<bool> sendRequest() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;
      final currentUser = await Amplify.Auth.getCurrentUser();
      final userId = currentUser.userId;

      final res = await http.post(
        Uri.parse("$baseUrl/collaborator-request"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({"userId": userId}),
      );

      if (res.statusCode != 200) return false;

      final prefs = await SharedPreferences.getInstance();
      final pendingKey = await _scopedKey(_pendingKeyBase);
      final lastRequestedKey = await _scopedKey(_lastRequestedKeyBase);
      final approvedNotifiedKey = await _scopedKey(_approvedNotifiedKeyBase);
      final pendingNotifiedKey = await _scopedKey(_pendingNotifiedKeyBase);
      await prefs.setBool(pendingKey, true);
      await prefs.setBool(lastRequestedKey, true);
      await prefs.setBool(approvedNotifiedKey, false);
      await prefs.setBool(pendingNotifiedKey, false);

      NotificationController.instance.addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: "Richiesta collaboratore inviata",
          message:
              "La tua richiesta è stata inviata. Ti avviseremo dopo la verifica.",
          timestamp: DateTime.now(),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final res = await http.get(
        Uri.parse("$baseUrl/collaborator-request/status"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
      );

      if (res.statusCode == 404) {
        await _syncLocalStatus(requested: false, enabled: false);
        return {"requested": false, "enabled": false, "available": false};
      }
      if (res.statusCode != 200) {
        return {"requested": false, "enabled": false, "available": true};
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final requested = data["requested"] == true;
      final enabled = data["enabled"] == true;
      await _syncLocalStatus(requested: requested, enabled: enabled);
      return {
        "requested": requested,
        "enabled": enabled,
        "available": true,
      };
    } catch (_) {
      return {"requested": false, "enabled": false, "available": true};
    }
  }

  static Future<void> _syncLocalStatus({
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

    if (enabled) {
      final approvedNotified = prefs.getBool(approvedNotifiedKey) ?? false;
      if (!approvedNotified) {
        NotificationController.instance.addNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: "Richiesta approvata",
            message:
                "Sei stato approvato come collaboratore. Ora puoi affiliare attività.",
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
            message: "La richiesta collaboratore è in attesa di approvazione.",
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
          message: "La richiesta collaboratore non è stata approvata.",
          timestamp: DateTime.now(),
        ),
      );
      await prefs.setBool(pendingKey, false);
      await prefs.setBool(lastRequestedKey, false);
      await prefs.setBool(approvedNotifiedKey, false);
      await prefs.setBool(pendingNotifiedKey, false);
    }
  }
}
