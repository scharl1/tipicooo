import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/registration.dart';
import 'package:tipicooo/logiche/navigation/app_routes.dart';
import 'package:tipicooo/widgets/apptextfield.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/theme/app_text_styles.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController = TextEditingController();
  final surnameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final repeatPasswordController = TextEditingController();
  final otpController = TextEditingController();

  bool isLoading = false;
  bool showOtpField = false;

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _doSignup() async {
    FocusScope.of(context).unfocus();

    final name = nameController.text.trim();
    final surname = surnameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final repeatPassword = repeatPasswordController.text.trim();

    if (name.isEmpty) return _showMessage("Inserisci il nome");
    if (surname.isEmpty) return _showMessage("Inserisci il cognome");
    if (!email.contains("@") || !email.contains(".")) return _showMessage("Email non valida");
    if (password.length < 6) return _showMessage("La password deve avere almeno 6 caratteri");
    if (password != repeatPassword) return _showMessage("Le password non coincidono");

    setState(() => isLoading = true);

    final result = await Registration.signUp(
      email: email,
      name: name,
      surname: surname,
      password: password,
      repeatPassword: repeatPassword,
    );

    setState(() => isLoading = false);

    if (!result.success) {
      _showMessage(result.message);
      return;
    }

    setState(() => showOtpField = true);
    _showMessage("Codice inviato alla tua email.");
  }

  Future<void> _confirmOtp() async {
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final otp = otpController.text.trim();

    if (otp.isEmpty) return _showMessage("Inserisci il codice OTP");

    setState(() => isLoading = true);

    final result = await Registration.confirmSignUp(
      email: email,
      code: otp,
    );

    setState(() => isLoading = false);

    if (!result.success) {
      _showMessage(result.message);
      return;
    }

    _showMessage("Registrazione completata! Ora accedi.");
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: "Registrazione",
      showBack: true,
      showBell: false,
      showHome: true,
      showLogout: false,

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),

            if (!showOtpField) ...[
              AppTextField(controller: nameController, label: "Nome"),
              const SizedBox(height: 20),

              AppTextField(controller: surnameController, label: "Cognome"),
              const SizedBox(height: 20),

              AppTextField(controller: emailController, label: "Email"),
              const SizedBox(height: 20),

              AppTextField(controller: passwordController, label: "Password", obscure: true),
              const SizedBox(height: 20),

              AppTextField(controller: repeatPasswordController, label: "Ripeti Password", obscure: true),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: BlueNarrowButton(
                  label: isLoading ? "Attendere..." : "Registrati",
                  onPressed: isLoading ? () {} : _doSignup,
                ),
              ),
            ],

            if (showOtpField) ...[
              AppTextField(controller: otpController, label: "Codice OTP"),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: BlueNarrowButton(
                  label: isLoading ? "Verifica..." : "Conferma Codice",
                  onPressed: isLoading ? () {} : _confirmOtp,
                ),
              ),
            ],

            const SizedBox(height: 20),

            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              },
              child: const Text(
                "Hai già un account? Accedi",
                style: AppTextStyles.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}