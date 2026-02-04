import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:tipicooo/widgets/base_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: "Login",
      showBack: true,
      isLoading: isLoading,
      scrollable: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildLoginUI(),
      ),
    );
  }

  Widget _buildLoginUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Accedi al tuo account",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 25),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _loginWithHostedUI,
            child: const Text("Accedi con Cognito"),
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, "/signup");
            },
            child: const Text("Non hai un account? Registrati"),
          ),
        ),
      ],
    );
  }

  Future<void> _loginWithHostedUI() async {
    setState(() => isLoading = true);

    try {
      await Amplify.Auth.signInWithWebUI();
      if (!mounted) return;

      // ⭐ VERSIONE CORRETTA PER AMPLIFY 2.x
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final tokens = session.userPoolTokensResult.value;
      print("TOKEN_ADMIN: ${tokens.idToken.raw}");

      Navigator.pushNamedAndRemoveUntil(context, "/user", (_) => false);
    } catch (e) {
      debugPrint("Errore login Hosted UI: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore durante il login")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}