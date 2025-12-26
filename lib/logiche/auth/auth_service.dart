import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:tipicooo/amplifyconfiguration.dart';

class AuthService {
  AuthService._privateConstructor();
  static final AuthService _instance = AuthService._privateConstructor();
  factory AuthService() => _instance;

  static bool _isConfigured = false;

  static Future<void> configure() async {
    if (_isConfigured) return;

    try {
      final auth = AmplifyAuthCognito();
      await Amplify.addPlugin(auth);
      await Amplify.configure(amplifyconfig);
      _isConfigured = true;
      debugPrint("Amplify configurato correttamente");
    } catch (e) {
      debugPrint("Amplify già configurato o errore: $e");
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );
      return result.isSignedIn;
    } on AuthException catch (e) {
      debugPrint('Errore login: ${e.message}');
      return false;
    }
  }

  Future<bool> signUpAsConsumer({
    required String email,
    required String password,
  }) async {
    try {
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            CognitoUserAttributeKey.email: email,
            const CognitoUserAttributeKey.custom('role'): 'consumatore_finale',
          },
        ),
      );
      return result.isSignUpComplete;
    } on AuthException catch (e) {
      debugPrint('Errore signup: ${e.message}');
      return false;
    }
  }

  Future<bool> signUpAsAdmin({
    required String email,
    required String password,
  }) async {
    try {
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            CognitoUserAttributeKey.email: email,
            const CognitoUserAttributeKey.custom('role'): 'admin',
          },
        ),
      );
      return result.isSignUpComplete;
    } on AuthException catch (e) {
      debugPrint('Errore signup admin: ${e.message}');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
    } on AuthException catch (e) {
      debugPrint('Errore logout: ${e.message}');
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } on AuthException catch (e) {
      debugPrint('Errore fetch session: ${e.message}');
      return false;
    }
  }

  Future<Map<String, String>> getUserAttributes() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      return {
        for (var a in attributes) a.userAttributeKey.key: a.value,
      };
    } on AuthException catch (e) {
      debugPrint('Errore fetch attributes: ${e.message}');
      return {};
    }
  }

  Future<String?> getUserRole() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();

      final roleAttribute = attributes.firstWhere(
        (a) => a.userAttributeKey.key == 'custom:role',
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.custom('role'),
          value: '',
        ),
      );

      if (roleAttribute.value.isEmpty) return null;

      return roleAttribute.value;
    } on AuthException catch (e) {
      debugPrint('Errore fetch role: ${e.message}');
      return null;
    }
  }
}