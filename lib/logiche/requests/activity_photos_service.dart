import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'file_bytes.dart';

class ActivityPhotosService {
  static const String baseUrl =
      "https://efs0gx9nm4.execute-api.eu-south-1.amazonaws.com/prod";

  static Future<Map<String, dynamic>?> _presign({
    required String requestId,
    required String fileName,
    required String contentType,
    required String kind,
  }) async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final response = await http.post(
        Uri.parse("$baseUrl/activity-photos-presign"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "requestId": requestId,
          "fileName": fileName,
          "contentType": contentType,
          "kind": kind,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("Errore presign: ${response.body}");
        return null;
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Errore presign: $e");
      return null;
    }
  }

  static Future<bool> _uploadBytes({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          "Content-Type": contentType,
        },
        body: bytes,
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Errore upload: $e");
      return false;
    }
  }

  static Future<bool> deletePhoto({
    required String requestId,
    required String key,
  }) async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final idToken = session.userPoolTokensResult.value.idToken.raw;

      final response = await http.post(
        Uri.parse("$baseUrl/activity-photo-delete"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "requestId": requestId,
          "key": key,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Errore delete foto: $e");
      return false;
    }
  }

  static Future<Map<String, String>?> uploadFromPickerResult({
    required String pickerResult,
    required String requestId,
    required String kind,
  }) async {
    final parsed = _parsePickerResult(pickerResult);
    if (parsed == null) return null;

    final presign = await _presign(
      requestId: requestId,
      fileName: parsed.fileName,
      contentType: parsed.contentType,
      kind: kind,
    );
    if (presign == null) return null;

    final uploadUrl = presign["uploadUrl"]?.toString();
    final key = presign["key"]?.toString();
    if (uploadUrl == null || key == null) return null;

    final ok = await _uploadBytes(
      uploadUrl: uploadUrl,
      bytes: parsed.bytes,
      contentType: parsed.contentType,
    );

    if (!ok) return null;

    return {"key": key};
  }

  static _ParsedResult? _parsePickerResult(String result) {
    if (kIsWeb && result.startsWith("data:")) {
      final match = RegExp(r'^data:(.*?);base64,(.*)$').firstMatch(result);
      if (match == null) return null;
      final contentType = match.group(1) ?? "image/jpeg";
      final b64 = match.group(2) ?? "";
      final bytes = base64Decode(b64);
      final fileName = "photo_${DateTime.now().millisecondsSinceEpoch}.jpg";
      return _ParsedResult(
        bytes: bytes,
        contentType: contentType,
        fileName: fileName,
      );
    }

    // Mobile/desktop path
    try {
      final parts = result.split(RegExp(r'[\\\\/]'));
      final fileName = parts.isNotEmpty ? parts.last : "photo.jpg";
      final ext = fileName.contains('.') ? fileName.split('.').last : "jpg";
      final contentType = _contentTypeFromExt(ext);
      final fileBytes = _readFileBytes(result);
      if (fileBytes == null) return null;
      return _ParsedResult(
        bytes: fileBytes,
        contentType: contentType,
        fileName: fileName,
      );
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _readFileBytes(String path) {
    if (kIsWeb) return null;
    return readFileBytes(path);
  }

  static String _contentTypeFromExt(String ext) {
    final e = ext.toLowerCase();
    if (e == "png") return "image/png";
    if (e == "jpeg" || e == "jpg") return "image/jpeg";
    return "application/octet-stream";
  }
}

class _ParsedResult {
  final Uint8List bytes;
  final String contentType;
  final String fileName;

  _ParsedResult({
    required this.bytes,
    required this.contentType,
    required this.fileName,
  });
}
