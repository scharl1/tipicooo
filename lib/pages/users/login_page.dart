import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/auth/auth_service.dart';
import 'package:tipicooo/widgets/base_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // CONTROLLER LOGIN
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // CONTROLLER RECUPERO PASSWORD
  final TextEditingController resetEmailController = TextEditingController();
  final TextEditingController resetCodeController = TextEditingController();
  final TextEditingController resetNewPasswordController = TextEditingController();

  bool isLoading = false;

  // 1 = login, 2 = forgot email, 3 = forgot code
  int step = 1;

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: _getHeaderTitle(),
      showBack: true,
      isLoading: isLoading,
      scrollable: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildStep(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER TITLE DINAMICO
  // ---------------------------------------------------------------------------

  String _getHeaderTitle() {
    switch (step) {
      case 2:
        return "Recupera password";
      case 3:
        return "Reimposta password";
      default:
        return "Login";
    }
  }

  // ---------------------------------------------------------------------------
  // SWITCHER DEI 3 STATI
  // ---------------------------------------------------------------------------

  Widget _buildStep() {
    switch (step) {
      case 2:
        return _buildForgotEmail();
      case 3:
        return _buildForgotCode();
      default:
        return _buildLoginForm();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1 — LOGIN
  // ---------------------------------------------------------------------------

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Accedi al tuo account",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 25),

        const Text("Email", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: emailController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Inserisci la tua email",
          ),
        ),

        const SizedBox(height: 20),

        const Text("Password", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Inserisci la tua password",
          ),
        ),

        const SizedBox(height: 30),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _login,
            child: const Text("Accedi"),
          ),
        ),

        const SizedBox(height: 15),

        Center(
          child: TextButton(
            onPressed: () => setState(() => step = 2),
            child: const Text("Hai dimenticato la password?"),
          ),
        ),

        const SizedBox(height: 10),

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

  Future<void> _login() async {
    setState(() => isLoading = true);

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    final result = await AuthService.instance.signIn(
      email: email,
      password: password,
    );

    setState(() => isLoading = false);

    if (result == "ok") {
      Navigator.pushNamedAndRemoveUntil(context, "/user", (_) => false);
      return;
    }

    if (result == "unconfirmed") {
      Navigator.pushNamed(
        context,
        "/signup",
        arguments: {"mode": "otp", "email": email},
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Credenziali non valide")),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2 — INSERIMENTO EMAIL PER RECUPERO
  // ---------------------------------------------------------------------------

  Widget _buildForgotEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Inserisci la tua email",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: resetEmailController,
          decoration: const InputDecoration(
            labelText: "Email",
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _sendResetCode,
          child: const Text("Invia codice"),
        ),
      ],
    );
  }

  Future<void> _sendResetCode() async {
    setState(() => isLoading = true);

    final ok = await AuthService.instance.resetPassword(
      resetEmailController.text.trim(),
    );

    setState(() => isLoading = false);

    if (ok) {
      setState(() => step = 3);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore durante l'invio del codice")),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 3 — CODICE + NUOVA PASSWORD
  // ---------------------------------------------------------------------------

  Widget _buildForgotCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Inserisci il codice ricevuto",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: resetCodeController,
          decoration: const InputDecoration(
            labelText: "Codice",
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 20),

        TextField(
          controller: resetNewPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: "Nuova password",
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _resetPassword,
          child: const Text("Conferma"),
        ),
      ],
    );
  }

  Future<void> _resetPassword() async {
    setState(() => isLoading = true);

    final ok = await AuthService.instance.confirmResetPassword(
      email: resetEmailController.text.trim(),
      confirmationCode: resetCodeController.text.trim(),
      newPassword: resetNewPasswordController.text.trim(),
    );

    setState(() => isLoading = false);

    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore durante il reset della password")),
      );
    }
  }
}