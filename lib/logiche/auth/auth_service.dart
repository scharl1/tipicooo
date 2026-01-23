import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:tipicooo/amplifyconfiguration.dart';
import 'auth_state.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static bool _isConfigured = false;

  // ---------------------------------------------------------------------------
  // CONFIGURAZIONE AMPLIFY
  // ---------------------------------------------------------------------------

  static Future<void> configure() async {
    if (_isConfigured) return;

    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(amplifyconfig);
      _isConfigured = true;
      debugPrint("Amplify configurato correttamente");
    } catch (e) {
      debugPrint("Amplify già configurato o errore: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------------

  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      debugPrint("🔥 SIGN-IN RESULT:");
      debugPrint("isSignedIn: ${result.isSignedIn}");
      debugPrint("nextStep: ${result.nextStep.signInStep}");
      debugPrint("additionalInfo: ${result.nextStep.additionalInfo}");

      // LOGIN OK
      if (result.isSignedIn) {
        AuthState.setLoggedIn();
        return "ok";
      }

      // UTENTE NON CONFERMATO
      if (result.nextStep.signInStep == AuthSignInStep.confirmSignUp) {
        return "unconfirmed";
      }

      // PASSWORD SBAGLIATA
      if (result.nextStep.signInStep == AuthSignInStep.done &&
          !result.isSignedIn) {
        return "invalid";
      }

      return "error";

    } on UserNotConfirmedException {
      return "unconfirmed";

    } on UserNotFoundException {
      return "not_found";

    } on AuthException catch (e) {
      debugPrint("🔥 ERRORE COGNITO LOGIN:");
      debugPrint("Tipo: ${e.runtimeType}");
      debugPrint("Messaggio: ${e.message}");

      if (e.message.contains("Incorrect username or password")) {
        return "invalid";
      }

      return "error";
    }
  }

  // ---------------------------------------------------------------------------
  // SIGNUP CONSUMATORE
  // ---------------------------------------------------------------------------

  Future<SignUpResult?> signUpAsConsumer({
    required String email,
    required String password,
    required String name,
    required String surname,
  }) async {
    try {
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            CognitoUserAttributeKey.email: email,
            CognitoUserAttributeKey.givenName: name,
            CognitoUserAttributeKey.familyName: surname,
            const CognitoUserAttributeKey.custom('role'): 'consumatore_finale',
          },
        ),
      );

      return result;

    } on UsernameExistsException {
      debugPrint("Utente già esistente");
      return null;

    } on AuthException catch (e) {
      debugPrint("Errore signup: ${e.message}");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // SIGNUP ADMIN
  // ---------------------------------------------------------------------------

  Future<SignUpResult?> signUpAsAdmin({
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

      return result;

    } on UsernameExistsException {
      debugPrint("Admin già esistente");
      return null;

    } on AuthException catch (e) {
      debugPrint("Errore signup admin: ${e.message}");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CONFERMA SIGNUP (OTP)
  // ---------------------------------------------------------------------------

  Future<bool> confirmSignUp({
    required String email,
    required String code,
  }) async {
    try {
      await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: code,
      );
      return true;
    } on AuthException catch (e) {
      debugPrint("Errore conferma signup: ${e.message}");
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // REINVIO CODICE OTP
  // ---------------------------------------------------------------------------

  Future<void> resendSignUpCode(String email) async {
    try {
      await Amplify.Auth.resendSignUpCode(username: email);
      debugPrint("Codice reinviato");
    } on AuthException catch (e) {
      debugPrint("Errore reinvio codice: ${e.message}");
    }
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  Future<void> logout() async {
    try {
      await Amplify.Auth.signOut(
        options: const SignOutOptions(globalSignOut: true),
      );

      AuthState.setLoggedOut();

    } on AuthException catch (e) {
      debugPrint("Errore logout: ${e.message}");
    }
  }

  // ---------------------------------------------------------------------------
  // ATTRIBUTI UTENTE
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> getUserAttributes() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      return {
        for (var a in attributes) a.userAttributeKey.key: a.value,
      };
    } on AuthException catch (e) {
      debugPrint("Errore fetch attributes: ${e.message}");
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
      debugPrint("Errore fetch role: ${e.message}");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // RESET PASSWORD
  // ---------------------------------------------------------------------------

  Future<bool> resetPassword(String email) async {
    try {
      await Amplify.Auth.resetPassword(username: email);
      return true;

    } on UserNotFoundException {
      debugPrint("Utente non trovato");
      return false;

    } on AuthException catch (e) {
      debugPrint("Errore reset password: ${e.message}");
      return false;
    }
  }

  Future<bool> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
      return true;

    } on AuthException catch (e) {
      debugPrint("Errore conferma reset password: ${e.message}");
      return false;
    }
  }
}