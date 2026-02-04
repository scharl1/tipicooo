import 'dart:convert';
import 'admin_service.dart';

class AdminRequestsService {
  static Future<List<dynamic>> getPendingRequests() async {
    final res = await AdminService.get("/admin-request-list");

    if (res.statusCode != 200) {
      throw Exception("Errore caricamento richieste");
    }

    return jsonDecode(res.body);
  }
}