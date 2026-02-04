import 'admin_service.dart';

class AdminActionsService {
  static Future<bool> approveUser(String userId) async {
    final res = await AdminService.post("/admin-approve", {
      "userId": userId,
    });

    return res.statusCode == 200;
  }

  static Future<bool> rejectUser(String userId) async {
    final res = await AdminService.post("/admin-reject", {
      "userId": userId,
    });

    return res.statusCode == 200;
  }

  static Future<bool> deleteUser(String userId) async {
    final res = await AdminService.delete("/admin-delete/$userId");
    return res.statusCode == 200;
  }
}