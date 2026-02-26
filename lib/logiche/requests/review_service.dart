import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';

class ReviewService {
  static const String baseUrl =
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod";

  static const String _reviewsKeyBase = "purchase_reviews_map";

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

  static Future<Map<String, dynamic>> _loadLocalMap() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopedKey(_reviewsKeyBase);
    final raw = prefs.getString(key) ?? "{}";
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  static Future<Set<String>> getLocallyReviewedPurchaseIds() async {
    final map = await _loadLocalMap();
    final out = <String>{};
    map.forEach((key, value) {
      final id = key.toString().trim();
      if (id.isEmpty) return;
      if (value is Map && value.isNotEmpty) {
        out.add(id);
      } else if (value is Map<String, dynamic> && value.isNotEmpty) {
        out.add(id);
      }
    });
    return out;
  }

  static Future<void> _saveLocalMap(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopedKey(_reviewsKeyBase);
    await prefs.setString(key, jsonEncode(data));
  }

  static Future<void> _saveLocalReview({
    required String purchaseId,
    required Map<String, dynamic> payload,
  }) async {
    final map = await _loadLocalMap();
    map[purchaseId] = payload;
    await _saveLocalMap(map);
  }

  static Future<Map<String, dynamic>?> fetchMyReview({
    required String purchaseId,
  }) async {
    final cleanPurchaseId = purchaseId.trim();
    if (cleanPurchaseId.isEmpty) return null;

    try {
      final headers = await _headers();
      final encoded = Uri.encodeComponent(cleanPurchaseId);
      final url = Uri.parse("$baseUrl/purchase-review-get?purchaseId=$encoded");
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final review = (data["review"] is Map<String, dynamic>)
              ? data["review"] as Map<String, dynamic>
              : data;
          if (review.isNotEmpty) {
            await _saveLocalReview(
              purchaseId: cleanPurchaseId,
              payload: review,
            );
            return review;
          }
        }
      }
    } catch (e) {
      debugPrint("Errore fetchMyReview: $e");
    }

    final map = await _loadLocalMap();
    final local = map[cleanPurchaseId];
    if (local is Map<String, dynamic>) return local;
    if (local is Map) {
      return local.cast<String, dynamic>();
    }
    return null;
  }

  static Future<bool> upsertReview({
    required String purchaseId,
    required String activityRequestId,
    required int score1,
    required int score2,
    required int score3,
    required String score1Label,
    required String score2Label,
    required String score3Label,
    required bool wouldRecommend,
    String notRecommendReason = "",
  }) async {
    final cleanPurchaseId = purchaseId.trim();
    final cleanActivityId = activityRequestId.trim();
    if (cleanPurchaseId.isEmpty || cleanActivityId.isEmpty) return false;

    final payload = <String, dynamic>{
      "purchaseId": cleanPurchaseId,
      "activityRequestId": cleanActivityId,
      // Nuovo formato dinamico
      "score1": score1,
      "score2": score2,
      "score3": score3,
      "score1Label": score1Label.trim(),
      "score2Label": score2Label.trim(),
      "score3Label": score3Label.trim(),
      // Compatibilità con formato precedente
      "serviceScore": score1,
      "cleanlinessScore": score2,
      "courtesyScore": score3,
      "wouldRecommend": wouldRecommend,
      "notRecommendReason": notRecommendReason.trim(),
      "updatedAt": DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final headers = await _headers();
      final url = Uri.parse("$baseUrl/purchase-review-upsert");
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) {
        debugPrint(
          "purchase-review-upsert failed: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("Errore upsertReview: $e");
    }

    await _saveLocalReview(
      purchaseId: cleanPurchaseId,
      payload: payload,
    );
    return true;
  }
}
