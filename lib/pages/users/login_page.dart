import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_controller.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/logiche/navigation/nav_routes.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/widgets/apptextfield.dart';
import 'package:tipicooo/theme/app_text_styles.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final otpController = TextEditingController();

  // Reset password fields
  bool resetMode = false;
  bool codeSent = false;
  final resetCodeController = TextEditingController();
  final newPasswordController = TextEditingController();

  late AuthController auth;

  @override
  void initState() {
    super.initState();
    auth = AuthController(onUpdate: () => setState(() {}));
  }

  void _notify() => setState(() {});

  Future<void> sendResetCode() async {
    auth.isLoading = true;
    _notify();

    final ok = await AuthService().resetPassword(
      emailController.text.trim(),
    );

    auth.isLoading = false;
    codeSent = ok;
    _notify();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? "Codice inviato alla tua email"
            : "Errore durante l'invio del codice"),
      ),
    );
  }

  Future<void> confirmReset() async {
    auth.isLoading = true;
    _notify();

    final ok = await AuthService().confirmResetPassword(
      email: emailController.text.trim(),
      confirmationCode: resetCodeController.text.trim(),
      newPassword: newPasswordController.text.trim(),
    );

    auth.isLoading = false;
    _notify();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? "Password reimpostata correttamente"
            : "Errore nella conferma del codice"),
      ),
    );

    if (ok) {
      resetMode = false;
      codeSent = false;
      resetCodeController.clear();
      newPasswordController.clear();
      _notify();
    }
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),

            AppTextField(
              controller: emailController,
              label: "Email",
            ),

            const SizedBox(height: 20),

            if (!resetMode) ...[
              // NORMAL LOGIN MODE
              AppTextField(
                controller: passwordController,
                label: "Password",
                obscure: true,
              ),

              // ⭐ LINK RECUPERA PASSWORD
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    resetMode = true;
                    _notify();
                  },
                  child: const Text(
                    "Recupera password",
                    style: AppTextStyles.body,
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],

            if (resetMode) ...[
              // RESET PASSWORD MODE
              const SizedBox(height: 10),

              BlueNarrowButton(
                label: "Invia codice",
                onPressed: sendResetCode,
              ),

              if (codeSent) ...[
                const SizedBox(height: 20),

                AppTextField(
                  controller: resetCodeController,
                  label: "Codice OTP",
                ),

                const SizedBox(height: 20),

                AppTextField(
                  controller: newPasswordController,
                  label: "Nuova password",
                  obscure: true,
                ),

                const SizedBox(height: 20),

                RoundedYellowButton(
                  label: "Conferma reset",
                  icon: Icons.check,
                  onPressed: confirmReset,
                ),
              ],

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  resetMode = false;
                  codeSent = false;
                  _notify();
                },
                child: const Text(
                  "Torna al login",
                  style: AppTextStyles.body,
                ),
              ),
            ],

            if (!resetMode) ...[
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
                    style: AppTextStyles.body,
                  ),
                ),

                const SizedBox(height: 20),
              ],

              SizedBox(
                width: double.infinity,
                child: RoundedYellowButton(
                  label: "Accedi",
                  icon: Icons.login,
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
              ),

              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, "/signup");
                },
                child: const Text(
                  "Non hai un account? Registrati",
                  style: AppTextStyles.body,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}