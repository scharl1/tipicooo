import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:tipicooo/pages/users/user_page.dart';
import 'package:tipicooo/pages/home_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool isLoading = true;
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();

      if (!mounted) return;

      setState(() {
        isLoggedIn = session.isSignedIn;
        isLoading = false;
      });

      _navigate();
    } catch (e) {
      safePrint("Errore fetchAuthSession: $e");

      if (!mounted) return;

      setState(() {
        isLoggedIn = false;
        isLoading = false;
      });

      _navigate();
    }
  }

  void _navigate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isLoggedIn ? const UserPage() : const HomePage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}