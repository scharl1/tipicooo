import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';

class DashboardController {
  bool isLoading = false;
  String? userName;
  String userRole = "user";

  VoidCallback? onUpdate;

  DashboardController({this.onUpdate});

  void _notify() {
    if (onUpdate != null) onUpdate!();
  }

  Future<void> loadUserData() async {
    isLoading = true;
    _notify();

    final attributes = await AuthService().getUserAttributes();
    final role = await AuthService().getUserRole();

    userName = attributes['given_name'] ??
        attributes['name'] ??
        attributes['email'] ??
        "Utente";

    userRole = role ?? "user";

    isLoading = false;
    _notify();
  }
}