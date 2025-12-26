import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'app_routes.dart';

class NavRoutes {
  NavRoutes._privateConstructor();
  static final NavRoutes _instance = NavRoutes._privateConstructor();
  factory NavRoutes() => _instance;

  /// Da usare SOLO dopo il login
  Future<void> navigateAfterLogin(BuildContext context) async {
    final role = await AuthService().getUserRole();

    if (role == "admin") {
      Navigator.pushReplacementNamed(context, AppRoutes.admin);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.user);
    }
  }
}