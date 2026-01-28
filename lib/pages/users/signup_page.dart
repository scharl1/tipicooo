import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:tipicooo/widgets/base_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: "Registrazione",
      showBack: true,
      isLoading: isLoading,
      scrollable: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildSignupUI(),
      ),
    );
  }

  Widget _buildSignupUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Crea un nuovo account",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 25),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _signupWithHostedUI,
            child: const Text("Registrati con Cognito"),
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, "/login");
            },
            child: const Text("Hai già un account? Accedi"),
          ),
        ),
      ],
    );
  }

  Future<void> _signupWithHostedUI() async {
    setState(() => isLoading = true);

    try {
      await Amplify.Auth.signInWithWebUI();
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, "/user", (_) => false);
    } catch (e) {
      debugPrint("Errore signup Hosted UI: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore durante la registrazione")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}