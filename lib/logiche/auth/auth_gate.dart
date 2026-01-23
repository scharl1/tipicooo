import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_state.dart';
import 'package:tipicooo/pages/home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthState.isLoggedIn,
      builder: (context, loggedIn, _) {
        // ⭐ L’utente loggato deve andare in HomePage
        return loggedIn ? HomePage() : HomePage();
      },
    );
  }
}