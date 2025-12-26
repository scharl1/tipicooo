import 'package:amplify_flutter/amplify_flutter.dart';

class RegistrationResult {
  final bool success;
  final String message;

  RegistrationResult(this.success, this.message);
}

class Registration {
  /// LOGIN CON GESTIONE OTP UNIVERSALE
  static Future<RegistrationResult> signIn({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      return RegistrationResult(false, "Inserisci email e password");
    }

    try {
      final res = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      final step = res.nextStep.signInStep;

      // 🔥 LOGIN COMPLETO
      if (step == AuthSignInStep.done) {
        return RegistrationResult(true, "LOGIN_OK");
      }

      // 🔥 QUALSIASI ALTRO STEP = OTP RICHIESTO
      return RegistrationResult(false, "OTP_REQUIRED");

    } on AuthException catch (e) {
      return RegistrationResult(false, e.message);
    } catch (e) {
      return RegistrationResult(false, "Errore durante il login");
    }
  }

  /// REGISTRAZIONE
  static Future<RegistrationResult> signUp({
    required String email,
    required String name,
    required String surname,
    required String password,
    required String repeatPassword,
  }) async {
    if (email.isEmpty || name.isEmpty || surname.isEmpty || password.isEmpty || repeatPassword.isEmpty) {
      return RegistrationResult(false, "Compila tutti i campi");
    }

    if (!email.contains("@") || !email.contains(".")) {
      return RegistrationResult(false, "Email non valida");
    }

    if (password.length < 6) {
      return RegistrationResult(false, "La password deve avere almeno 6 caratteri");
    }

    if (password != repeatPassword) {
      return RegistrationResult(false, "Le password non coincidono");
    }

    try {
      final res = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            CognitoUserAttributeKey.email: email,
            CognitoUserAttributeKey.givenName: name,
            CognitoUserAttributeKey.familyName: surname,
          },
        ),
      );

      if (res.isSignUpComplete) {
        return RegistrationResult(true, "SIGNUP_OK");
      } else {
        return RegistrationResult(true, "OTP_REQUIRED");
      }

    } on AuthException catch (e) {
      return RegistrationResult(false, e.message);
    } catch (e) {
      return RegistrationResult(false, "Errore durante la registrazione");
    }
  }

  /// CONFERMA REGISTRAZIONE (OTP)
  static Future<RegistrationResult> confirmSignUp({
    required String email,
    required String code,
  }) async {
    try {
      final res = await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: code,
      );

      if (res.isSignUpComplete) {
        return RegistrationResult(true, "CONFIRMED");
      } else {
        return RegistrationResult(false, "Conferma non completata");
      }

    } on AuthException catch (e) {
      return RegistrationResult(false, e.message);
    }
  }

  /// REINVIO CODICE OTP
  static Future<RegistrationResult> resendCode({
    required String email,
  }) async {
    try {
      await Amplify.Auth.resendSignUpCode(username: email);
      return RegistrationResult(true, "Codice reinviato");
    } on AuthException catch (e) {
      return RegistrationResult(false, e.message);
    }
  }

  /// RESET PASSWORD (INVIA CODICE)
  static Future<RegistrationResult> resetPassword({
    required String email,
  }) async {
    try {
      await Amplify.Auth.resetPassword(username: email);
      return RegistrationResult(true, "Codice inviato all’email");
    } on AuthException catch (e) {
      return RegistrationResult(false, e.message);
    }
  }

  /// CONFERMA RESET PASSWORD
  static Future<RegistrationResult> confirmResetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: code,
      );

      return RegistrationResult(true, "Password aggiornata");

    } on AuthException catch (e) {
      return RegistrationResult(false, e.message);
    }
  }
}