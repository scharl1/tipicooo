import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/widgets/base_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // CONTROLLER FORM REGISTRAZIONE
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();

  // CONTROLLER OTP
  final TextEditingController otpController = TextEditingController();

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    // ARGOMENTI PASSATI DAL LOGIN O DALLA REGISTRAZIONE
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final bool otpMode = args?["mode"] == "otp";
    final String? pendingEmail = args?["email"];

    return BasePage(
      headerTitle: otpMode ? "Conferma OTP" : "Registrazione",
      showBack: true,
      isLoading: isLoading,
      scrollable: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: otpMode
            ? _buildOtpSection(pendingEmail)
            : _buildSignupForm(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORM REGISTRAZIONE
  // ---------------------------------------------------------------------------

  Widget _buildSignupForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Crea un nuovo account",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Nome"),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: surnameController,
          decoration: const InputDecoration(labelText: "Cognome"),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: "Email"),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Password"),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: () async {
            setState(() => isLoading = true);

            final result = await AuthService.instance.signUpAsConsumer(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
              name: nameController.text.trim(),
              surname: surnameController.text.trim(),
            );

            setState(() => isLoading = false);

            if (result != null) {
              Navigator.pushNamed(
                context,
                "/signup",
                arguments: {
                  "mode": "otp",
                  "email": emailController.text.trim(),
                },
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Errore durante la registrazione")),
              );
            }
          },
          child: const Text("Registrati"),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SEZIONE OTP
  // ---------------------------------------------------------------------------

  Widget _buildOtpSection(String? email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Inserisci il codice ricevuto via email",
            style: TextStyle(fontSize: 18)),
        const SizedBox(height: 10),

        Text(
          email ?? "",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),

        TextField(
          controller: otpController,
          decoration: const InputDecoration(
            labelText: "Codice OTP",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: () async {
            setState(() => isLoading = true);

            final ok = await AuthService.instance.confirmSignUp(
              email: email!,
              code: otpController.text.trim(),
            );

            setState(() => isLoading = false);

            if (ok) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                "/user",
                (_) => false,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Codice non valido")),
              );
            }
          },
          child: const Text("Conferma"),
        ),

        TextButton(
          onPressed: () {
            AuthService.instance.resendSignUpCode(email!);
          },
          child: const Text("Reinvia codice"),
        ),
      ],
    );
  }
}