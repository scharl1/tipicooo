import 'dart:async';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'registration.dart';

class AuthController {
  bool isLoading = false;
  bool otpForSignup = false;

  int secondsRemaining = 0;
  Timer? timer;

  VoidCallback? onUpdate;

  AuthController({this.onUpdate});

  void _notify() {
    if (onUpdate != null) onUpdate!();
  }

  void startTimer() {
    secondsRemaining = 60;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining == 0) {
        t.cancel();
      } else {
        secondsRemaining--;
        _notify();
      }
    });
  }

  Future<String?> login(String email, String password) async {
    isLoading = true;
    _notify();

    final result = await Registration.signIn(
      email: email,
      password: password,
    );

    isLoading = false;
    _notify();

    final msg = (result.message).toLowerCase();
    print("DEBUG LOGIN MESSAGE: ${result.message}");

    // 🔥 intercetta TUTTE le varianti di "utente non confermato"
    if (msg.contains("not confirmed") ||
        msg.contains("usernotconfirmed") ||
        msg.contains("user is not confirmed") ||
        msg.contains("user is not confirmed.") ||
        msg.contains("otp_required")) {
      otpForSignup = true;
      startTimer();
      _notify();
      return null;
    }

    // Login OK
    if (result.success && result.message == "LOGIN_OK") {
      return "LOGIN_OK";
    }

    return result.message;
  }

  Future<String?> confirmOtpSignup(String email, String code) async {
    isLoading = true;
    _notify();

    try {
      final res = await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: code,
      );

      isLoading = false;
      _notify();

      if (res.isSignUpComplete) {
        otpForSignup = false;
        _notify();
        return "OK";
      } else {
        return "Codice non valido";
      }
    } on AuthException catch (e) {
      isLoading = false;
      _notify();
      return e.message;
    }
  }

  Future<String?> resendOtp(String email) async {
    try {
      await Amplify.Auth.resendSignUpCode(username: email);
      startTimer();
      _notify();
      return "Codice reinviato";
    } catch (e) {
      return "Errore nel reinvio del codice";
    }
  }
}