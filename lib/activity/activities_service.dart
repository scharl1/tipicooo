import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class ActivitiesService {
  ActivitiesService._();
  static final ActivitiesService instance = ActivitiesService._();

  static const String basePath = "/activities";

  // ---------------------------------------------------------------------------
  // GET /activities
  // ---------------------------------------------------------------------------
  Future<List<dynamic>> getActivities() async {
    try {
      final response = await Amplify.API.get(basePath).response;

      debugPrint("📥 GET /activities → ${response.statusCode}");

      if (response.statusCode == 200) {
        return jsonDecode(response.decodeBody());
      }

      return [];
    } catch (e) {
      debugPrint("Errore GET activities: $e");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // POST /activities
  // ---------------------------------------------------------------------------
  Future<bool> createActivity(Map<String, dynamic> data) async {
    try {
      // ⭐ Recupera l'utente Cognito
      final user = await Amplify.Auth.getCurrentUser();

      // ⭐ Aggiunge il campo obbligatorio "parent"
      data['parent'] = user.userId;

      final response = await Amplify.API.post(
        basePath,
        body: HttpPayload.json(data),
      ).response;

      debugPrint("📤 POST /activities → ${response.statusCode}");
      debugPrint("Risposta: ${response.decodeBody()}");

      return response.statusCode == 200 || response.statusCode == 201;

    } catch (e) {
      debugPrint("Errore POST activity: $e");
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // PUT /activities/{id}
  // ---------------------------------------------------------------------------
  Future<bool> updateActivity(String id, Map<String, dynamic> data) async {
    try {
      final response = await Amplify.API.put(
        "$basePath/$id",
        body: HttpPayload.json(data),
      ).response;

      debugPrint("📤 PUT /activities/$id → ${response.statusCode}");
      debugPrint("Risposta: ${response.decodeBody()}");

      return response.statusCode == 200;

    } catch (e) {
      debugPrint("Errore PUT activity: $e");
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE /activities/{id}
  // ---------------------------------------------------------------------------
  Future<bool> deleteActivity(String id) async {
    try {
      final response = await Amplify.API.delete("$basePath/$id").response;

      debugPrint("🗑️ DELETE /activities/$id → ${response.statusCode}");
      debugPrint("Risposta: ${response.decodeBody()}");

      return response.statusCode == 200;

    } catch (e) {
      debugPrint("Errore DELETE activity: $e");
      return false;
    }
  }
}