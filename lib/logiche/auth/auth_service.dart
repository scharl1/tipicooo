import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:tipicooo/amplifyconfiguration.dart';
import 'auth_state.dart';
import 'package:tipicooo/logiche/requests/user_request_service.dart';
import 'package:tipicooo/logiche/requests/activity_request_service.dart';
import 'package:tipicooo/logiche/requests/purchase_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static bool _isConfigured = false;

  // ---------------------------------------------------------------------------
  // CONFIGURAZIONE AMPLIFY
  // ---------------------------------------------------------------------------
  static Future<void> configure() async {
    if (_isConfigured) {
      debugPrint("⚠️ Amplify già configurato");
      return;
    }

    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.addPlugin(AmplifyAPI());
      await Amplify.configure(_resolvedAmplifyConfig());

      _isConfigured = true;
      debugPrint("✅ Amplify configurato");
    } catch (e, st) {
      debugPrint("❌ ERRORE CONFIGURAZIONE AMPLIFY:");
      debugPrint(e.toString());
      debugPrint(st.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // LOGIN / SIGNUP — HOSTED UI
  // ---------------------------------------------------------------------------
  Future<bool> signInWithHostedUI() async {
    try {
      final result = await Amplify.Auth.signInWithWebUI(
        options: const SignInWithWebUIOptions(
          pluginOptions: CognitoSignInWithWebUIPluginOptions(
            language: 'it',
          ),
        ),
      );
      if (result.isSignedIn) {
        await AuthState.initialize();
        // Evita ritardi in UI: dopo login navighiamo subito, poi
        // inizializziamo polling e sync in background.
        unawaited(UserRequestService.resetAdminPendingCount());
        unawaited(ActivityRequestService.resetAdminPendingCount());
        unawaited(UserRequestService.getUserStatus());
        unawaited(UserRequestService.startAdminPolling());
        unawaited(ActivityRequestService.startAdminPolling());
        unawaited(PurchaseService.startActivityPolling());
        return true;
      } else {
        await AuthState.setLoggedOut();
        return false;
      }
    } catch (e, st) {
      debugPrint("Errore login Hosted UI: $e");
      debugPrint(st.toString());
      await AuthState.setLoggedOut();
      return false;
    }
  }

  static String _resolvedAmplifyConfig() {
    final Map<String, dynamic> config = jsonDecode(amplifyconfig);
    final oauth =
        (((config["auth"] as Map<String, dynamic>)["plugins"]
                    as Map<String, dynamic>)["awsCognitoAuthPlugin"]
                as Map<String, dynamic>)["Auth"]
            as Map<String, dynamic>;
    final oauthDefault =
        (oauth["Default"] as Map<String, dynamic>)["OAuth"]
            as Map<String, dynamic>;

    if (kIsWeb) {
      final webOrigin = Uri.base.origin;
      final webRedirect = "$webOrigin/";
      oauthDefault["SignInRedirectURI"] = webRedirect;
      oauthDefault["SignOutRedirectURI"] = webRedirect;
    } else {
      oauthDefault["SignInRedirectURI"] = "tipicooo://auth";
      oauthDefault["SignOutRedirectURI"] = "tipicooo://signout";
    }

    return jsonEncode(config);
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------
  Future<void> logout() async {
    // Non blocchiamo l'UI sul signOut remoto (su web puo' impallarsi).
    final Future<void> signOutFuture = Amplify.Auth.signOut()
        .timeout(const Duration(seconds: 8))
        .then((_) {})
        .catchError((e) {
          debugPrint("Errore/timeout logout: $e");
        });

    UserRequestService.stopAdminPolling();
    ActivityRequestService.stopAdminPolling();
    PurchaseService.stopActivityPolling();
    await AuthState.setLoggedOut();

    // Fire-and-forget: completa in background.
    unawaited(signOutFuture);
  }

  // ---------------------------------------------------------------------------
  // LETTURA ATTRIBUTI UTENTE DAL TOKEN JWT (INCLUSO SUB)
  // ---------------------------------------------------------------------------
  Future<Map<String, String>> getUserAttributes() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      final tokens = session.userPoolTokensResult.valueOrNull;
      if (tokens == null) return {};

      final idToken = tokens.idToken.raw;
      final payload = _parseJwt(idToken);

      return {
        "sub": payload["sub"] ?? "",
        "email": payload["email"] ?? "",
        "given_name": payload["given_name"] ?? "",
        "family_name": payload["family_name"] ?? "",
      };
    } catch (e) {
      debugPrint("Errore getUserAttributes: $e");
      return {};
    }
  }

  Map<String, dynamic> _parseJwt(String token) {
    final parts = token.split('.');
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return json.decode(decoded);
  }

  // ---------------------------------------------------------------------------
  // OTTENERE IL TOKEN JWT
  // ---------------------------------------------------------------------------
  Future<String?> getIdToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();

      if (session is CognitoAuthSession) {
        final tokens = session.userPoolTokensResult.valueOrNull;
        return tokens?.idToken.raw;
      }

      return null;
    } catch (e) {
      debugPrint("Errore ottenimento token: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CONTROLLO SE L’UTENTE È ADMIN (gruppi Cognito)
  // ---------------------------------------------------------------------------
  Future<bool> isAdmin() async {
    try {
      final idToken = await getIdToken();
      if (idToken == null) return false;

      final parts = idToken.split('.');
      if (parts.length != 3) return false;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));

      final data = json.decode(decoded);

      final groups = data["cognito:groups"];
      if (groups is List && groups.map((e) => e.toString()).contains("admin")) {
        return true;
      }
      if (groups is String) {
        final normalized = groups.trim();
        if (normalized == "admin") return true;
        if (normalized.startsWith("[") && normalized.endsWith("]")) {
          try {
            final parsed = json.decode(normalized);
            if (parsed is List &&
                parsed.map((e) => e.toString()).contains("admin")) {
              return true;
            }
          } catch (_) {}
        }
        if (normalized.split(",").map((e) => e.trim()).contains("admin")) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint("Errore controllo admin: $e");
      return false;
    }
  }
}
