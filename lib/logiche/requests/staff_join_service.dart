import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/logiche/notifications/app_notification.dart';
import 'package:tipicooo/logiche/notifications/notification_controller.dart';
import 'package:tipicooo/logiche/config/api_endpoints.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffJoinService {
  static const String baseUrl =
      ApiEndpoints.adminBaseUrl;

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

  static const String _ownerPendingIdsKeyBase = "staff_owner_pending_ids";
  static const String _ownerPendingInitKeyBase = "staff_owner_pending_init";
  static const String _staffApprovedIdsKeyBase = "staff_my_approved_ids";
  static const String _staffApprovedInitKeyBase = "staff_my_approved_init";
  static const String _incomingInviteIdsKeyBase = "staff_my_invite_ids";
  static const String _incomingInviteInitKeyBase = "staff_my_invite_init";
  static String _lastInviterEmail = "";

  static String get lastInviterEmail => _lastInviterEmail;

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

  static Future<bool> requestJoin({
    required String activityRequestId,
    bool notifyLocal = true,
  }) async {
    try {
      _lastInviterEmail = "";
      final headers = await _headers();
      final url = Uri.parse("$baseUrl/staff-join-create");
      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"activityRequestId": activityRequestId}),
      );
      final ok = res.statusCode == 200;
      if (ok) {
        String inviterEmail = _extractInviterEmail(res.body);
        if (inviterEmail.isEmpty) {
          inviterEmail = await _lookupInviterEmailFromPublicMap(
            activityRequestId,
          );
        }
        _lastInviterEmail = inviterEmail;
        final title = inviterEmail.isNotEmpty
            ? "Richiesta da parte di $inviterEmail"
            : "Richiesta dipendente inviata";
        final message = inviterEmail.isNotEmpty
            ? "Richiesta da parte di $inviterEmail inviata. In attesa di conferma."
            : "La richiesta dovrà essere approvata dal proprietario. Grazie";
        if (notifyLocal) {
          NotificationController.instance.addNotification(
            AppNotification(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              message: message,
              timestamp: DateTime.now(),
              action: "open_staff_join",
            ),
          );
        }
      }
      return ok;
    } catch (e) {
      _lastInviterEmail = "";
      debugPrint("Errore requestJoin: $e");
      return false;
    }
  }

  static Future<String> _lookupInviterEmailFromPublicMap(
    String activityRequestId,
  ) async {
    try {
      final id = activityRequestId.trim();
      if (id.isEmpty) return "";
      final items = await ActivityRequestService.fetchApprovedActivitiesPublic();
      for (final item in items) {
        final rid = (item["requestId"] ?? "").toString().trim();
        if (rid != id) continue;
        final email = (item["email"] ?? item["activityEmail"] ?? "")
            .toString()
            .trim();
        if (_isEmail(email)) return email;
        break;
      }
      return "";
    } catch (_) {
      return "";
    }
  }

  static String _extractInviterEmail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return "";
      final data = decoded.cast<String, dynamic>();
      const keys = <String>[
        "ownerEmail",
        "owner_email",
        "inviterEmail",
        "inviter_email",
        "senderEmail",
        "sender_email",
        "activityEmail",
        "activity_email",
        "email",
      ];
      for (final key in keys) {
        final value = (data[key] ?? "").toString().trim();
        if (_isEmail(value)) return value;
      }
      return "";
    } catch (_) {
      return "";
    }
  }

  static bool _isEmail(String value) {
    if (value.isEmpty) return false;
    return RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(value);
  }

  static Future<void> checkOwnerPendingRequests() async {
    try {
      final activities = await ActivityRequestService.fetchActivitiesForMe();
      final owned = activities.where((a) {
        final status = (a["status"] ?? "").toString().trim().toLowerCase();
        if (status != "approved") return false;
        final roleType = (a["roleType"] ?? "").toString().trim().toLowerCase();
        return roleType == "owner";
      }).toList();
      if (owned.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final idsBase = await _scopedKey(_ownerPendingIdsKeyBase);
      final initBase = await _scopedKey(_ownerPendingInitKeyBase);

      for (final a in owned) {
        final activityRequestId = (a["requestId"] ?? "").toString().trim();
        if (activityRequestId.isEmpty) continue;

        final insegna = (a["insegna"] ?? "").toString().trim();
        final ragione = (a["ragione_sociale"] ?? "").toString().trim();
        final activityName = insegna.isNotEmpty
            ? insegna
            : (ragione.isNotEmpty ? ragione : "Attività");

        final pending = await listPending(activityRequestId: activityRequestId);
        final currentIds = pending
            .map((it) {
              final uid = (it["requesterUserId"] ?? "").toString().trim();
              final email = (it["requesterEmail"] ?? "").toString().trim();
              final createdAt = (it["createdAt"] ?? "").toString().trim();
              final key = uid.isNotEmpty
                  ? uid
                  : (email.isNotEmpty ? email : createdAt);
              return key;
            })
            .where((it) => it.isNotEmpty)
            .toSet();

        final idsKey = "${idsBase}_$activityRequestId";
        final initKey = "${initBase}_$activityRequestId";
        final initialized = prefs.getBool(initKey) ?? false;
        final lastIdsRaw = prefs.getString(idsKey) ?? "";
        final lastIds = lastIdsRaw
            .split("|")
            .map((it) => it.trim())
            .where((it) => it.isNotEmpty)
            .toSet();

        if (initialized) {
          final hasNew = currentIds.any((id) => !lastIds.contains(id));
          if (hasNew) {
            final count = pending.length;
            NotificationController.instance.addNotification(
              AppNotification(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: "Nuova richiesta dipendente",
                message: "$activityName: $count richieste in attesa.",
                timestamp: DateTime.now(),
                action: "open_staff_manage",
              ),
            );
          }
        }

        final sorted = currentIds.toList()..sort();
        await prefs.setString(idsKey, sorted.join("|"));
        await prefs.setBool(initKey, true);
      }
    } catch (e) {
      debugPrint("Errore checkOwnerPendingRequests: $e");
    }
  }

  static Future<void> checkMyStaffApprovals() async {
    try {
      final activities = await ActivityRequestService.fetchActivitiesForMe();
      final mineAsStaff = activities.where((a) {
        final status = (a["status"] ?? "").toString().trim().toLowerCase();
        if (status != "approved") return false;
        final roleType = (a["roleType"] ?? "").toString().trim().toLowerCase();
        return roleType == "staff" ||
            roleType == "employee" ||
            roleType == "cashier";
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      final idsKey = await _scopedKey(_staffApprovedIdsKeyBase);
      final initKey = await _scopedKey(_staffApprovedInitKeyBase);

      final currentIds = mineAsStaff
          .map((a) => (a["requestId"] ?? "").toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      final initialized = prefs.getBool(initKey) ?? false;
      final lastRaw = prefs.getString(idsKey) ?? "";
      final lastIds = lastRaw
          .split("|")
          .map((x) => x.trim())
          .where((x) => x.isNotEmpty)
          .toSet();

      if (initialized) {
        for (final a in mineAsStaff) {
          final id = (a["requestId"] ?? "").toString().trim();
          if (id.isEmpty || lastIds.contains(id)) continue;
          final insegna = (a["insegna"] ?? "").toString().trim();
          final ragione = (a["ragione_sociale"] ?? "").toString().trim();
          final activityName = insegna.isNotEmpty
              ? insegna
              : (ragione.isNotEmpty ? ragione : "attività");

          NotificationController.instance.addNotification(
            AppNotification(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: "Abilitazione pagamenti attiva",
              message:
                  "Sei stato abilitato ai pagamenti per $activityName. Ora puoi gestire le richieste.",
              timestamp: DateTime.now(),
              action: "open_activity_payments|$id",
            ),
          );
        }
      }

      final sorted = currentIds.toList()..sort();
      await prefs.setString(idsKey, sorted.join("|"));
      await prefs.setBool(initKey, true);
    } catch (e) {
      debugPrint("Errore checkMyStaffApprovals: $e");
    }
  }

  static Future<bool> sendInviteToEmail({
    required String activityRequestId,
    required String inviteeEmail,
  }) async {
    try {
      final headers = await _headers();
      final url = Uri.parse("$baseUrl/staff-invite-create");
      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "activityRequestId": activityRequestId.trim(),
          "inviteeEmail": inviteeEmail.trim().toLowerCase(),
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("Errore sendInviteToEmail: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMyInvites() async {
    try {
      final headers = await _headers();
      final url = Uri.parse("$baseUrl/staff-invite-my");
      final res = await http.get(url, headers: headers);
      if (res.statusCode != 200) return <Map<String, dynamic>>[];
      final data = jsonDecode(res.body);
      final items = (data is Map && data["items"] is List)
          ? data["items"] as List
          : <dynamic>[];
      return items
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (e) {
      debugPrint("Errore fetchMyInvites: $e");
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> checkMyIncomingInvites() async {
    try {
      final invites = await fetchMyInvites();
      final prefs = await SharedPreferences.getInstance();
      final idsKey = await _scopedKey(_incomingInviteIdsKeyBase);
      final initKey = await _scopedKey(_incomingInviteInitKeyBase);

      final currentIds = invites
          .map((it) {
            final inviteId = (it["inviteId"] ?? "").toString().trim();
            if (inviteId.isNotEmpty) return inviteId;
            final createdAt = (it["createdAt"] ?? "").toString().trim();
            final activityRequestId =
                (it["activityRequestId"] ?? "").toString().trim();
            return "$createdAt|$activityRequestId";
          })
          .where((it) => it.isNotEmpty)
          .toSet();

      final initialized = prefs.getBool(initKey) ?? false;
      final lastRaw = prefs.getString(idsKey) ?? "";
      final lastIds = lastRaw
          .split("|")
          .map((x) => x.trim())
          .where((x) => x.isNotEmpty)
          .toSet();

      for (final it in invites) {
        final inviteId = (it["inviteId"] ?? "").toString().trim();
        final createdAt = (it["createdAt"] ?? "").toString().trim();
        final activityRequestId = (it["activityRequestId"] ?? "").toString().trim();
        final id = inviteId.isNotEmpty ? inviteId : "$createdAt|$activityRequestId";
        if (id.isEmpty || lastIds.contains(id)) continue;

        final ownerEmail = (it["ownerEmail"] ?? "").toString().trim();
        final activityName = (it["activityName"] ?? "").toString().trim();
        final codeLabel = activityRequestId.isNotEmpty
            ? "Codice: $activityRequestId."
            : "";
        final activityLabel = activityName.isNotEmpty ? "$activityName. " : "";

        NotificationController.instance.addNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: ownerEmail.isNotEmpty
                ? "Richiesta da parte di $ownerEmail"
                : "Nuovo invito dipendente",
            message:
                "${activityLabel}Hai ricevuto un invito per lavorare in un'attività. $codeLabel Vai su 'Lavora in un'attività' per confermare.",
            timestamp: DateTime.now(),
            action: "open_staff_join",
          ),
        );
      }

      final sorted = currentIds.toList()..sort();
      await prefs.setString(idsKey, sorted.join("|"));
      if (!initialized) {
        await prefs.setBool(initKey, true);
      }
    } catch (e) {
      debugPrint("Errore checkMyIncomingInvites: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> listPending({
    required String activityRequestId,
  }) async {
    try {
      final headers = await _headers();
      final id = Uri.encodeComponent(activityRequestId.trim());
      final url = Uri.parse("$baseUrl/staff-join-list?activityRequestId=$id");
      final res = await http.get(url, headers: headers);
      if (res.statusCode != 200) return <Map<String, dynamic>>[];
      final data = jsonDecode(res.body);
      final items = (data is Map && data["items"] is List)
          ? data["items"] as List
          : <dynamic>[];
      return items
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (e) {
      debugPrint("Errore listPending: $e");
      return <Map<String, dynamic>>[];
    }
  }

  static Future<List<Map<String, dynamic>>> listMembers({
    required String activityRequestId,
  }) async {
    try {
      final headers = await _headers();
      final id = Uri.encodeComponent(activityRequestId.trim());
      final url = Uri.parse(
        "$baseUrl/staff-join-members?activityRequestId=$id",
      );
      final res = await http.get(url, headers: headers);
      if (res.statusCode != 200) return <Map<String, dynamic>>[];
      final data = jsonDecode(res.body);
      final items = (data is Map && data["items"] is List)
          ? data["items"] as List
          : <dynamic>[];
      return items
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (e) {
      debugPrint("Errore listMembers: $e");
      return <Map<String, dynamic>>[];
    }
  }

  static Future<List<Map<String, dynamic>>> listOwnerInvites({
    required String activityRequestId,
  }) async {
    try {
      final headers = await _headers();
      final id = Uri.encodeComponent(activityRequestId.trim());
      final url = Uri.parse("$baseUrl/staff-invite-owner?activityRequestId=$id");
      final res = await http.get(url, headers: headers);
      if (res.statusCode != 200) return <Map<String, dynamic>>[];
      final data = jsonDecode(res.body);
      final items = (data is Map && data["items"] is List)
          ? data["items"] as List
          : <dynamic>[];
      return items
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (e) {
      debugPrint("Errore listOwnerInvites: $e");
      return <Map<String, dynamic>>[];
    }
  }

  static Future<bool> approve({
    required String activityRequestId,
    required String staffUserId,
  }) async {
    try {
      final headers = await _headers();
      final url = Uri.parse("$baseUrl/staff-join-approve");
      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "activityRequestId": activityRequestId,
          "staffUserId": staffUserId,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("Errore approve staff: $e");
      return false;
    }
  }

  static Future<bool> reject({
    required String activityRequestId,
    required String staffUserId,
  }) async {
    try {
      final headers = await _headers();
      final url = Uri.parse("$baseUrl/staff-join-reject");
      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "activityRequestId": activityRequestId,
          "staffUserId": staffUserId,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("Errore reject staff: $e");
      return false;
    }
  }

  static Future<bool> removeMember({
    required String activityRequestId,
    required String staffUserId,
  }) async {
    try {
      final headers = await _headers();
      final url = Uri.parse("$baseUrl/staff-join-remove");
      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "activityRequestId": activityRequestId,
          "staffUserId": staffUserId,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("Errore removeMember staff: $e");
      return false;
    }
  }
}
