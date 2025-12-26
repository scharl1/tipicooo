import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_controller.dart';
import 'package:tipicooo/logiche/navigation/nav_routes.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/widgets/AppTextField.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final otpController = TextEditingController();

  late AuthController auth;

  @override
  void initState() {
    super.initState();
    auth = AuthController(onUpdate: () => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: "Login",
      showBack: true,
      showBell: false,
      showHome: false,
      showLogout: false,
      isLoading: auth.isLoading,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            AppTextField(
              controller: emailController,
              label: "Email",
            ),

            const SizedBox(height: 20),

            AppTextField(
              controller: passwordController,
              label: "Password",
              obscure: true,
            ),

            const SizedBox(height: 30),

            if (auth.otpForSignup) ...[
              AppTextField(
                controller: otpController,
                label: "Codice OTP",
                autofocus: true,
              ),
              const SizedBox(height: 20),

              BlueNarrowButton(
                label: "Conferma registrazione",
                onPressed: () async {
                  final msg = await auth.confirmOtpSignup(
                    emailController.text.trim(),
                    otpController.text.trim(),
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg ?? "Errore")),
                  );
                },
              ),

              TextButton(
                onPressed: auth.secondsRemaining == 0
                    ? () async {
                        final msg = await auth.resendOtp(
                          emailController.text.trim(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg ?? "")),
                        );
                      }
                    : null,
                child: Text(
                  auth.secondsRemaining == 0
                      ? "Reinvia codice"
                      : "Reinvia tra ${auth.secondsRemaining}s",
                ),
              ),

              const SizedBox(height: 20),
            ],

           RoundedYellowButton(
  label: "Accedi",
  icon: Icons.login, // icona a destra
  onPressed: () async {
    final msg = await auth.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    if (msg == "LOGIN_OK") {
      await NavRoutes().navigateAfterLogin(context);
    } else if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  },
),

            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, "/signup");
              },
              child: const Text("Non hai un account? Registrati"),
            ),
          ],
        ),
      ),
    );
  }
}