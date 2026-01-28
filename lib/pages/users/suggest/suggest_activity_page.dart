import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';

class SuggestActivityPage extends StatefulWidget {
  const SuggestActivityPage({super.key});

  @override
  State<SuggestActivityPage> createState() => _SuggestActivityPageState();
}

class _SuggestActivityPageState extends State<SuggestActivityPage> {
  final TextEditingController activityNameController = TextEditingController();
  final TextEditingController referenteController = TextEditingController();
  final TextEditingController activityEmailController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  bool isSending = false;

  // VALIDAZIONI
  bool isValidEmail(String email) {
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return regex.hasMatch(email.trim());
  }

  bool isValidActivityName(String text) {
    final cleaned = text.trim();

    if (cleaned.isEmpty) return false;

    // Non solo simboli
    if (RegExp(r'^[\.\-_,;:!@#\$%\^&\*\(\)\+=\/\\\|\[\]\{\}]+$')
        .hasMatch(cleaned)) {
      return false;
    }

    // Non solo numeri
    if (RegExp(r'^\d+$').hasMatch(cleaned)) return false;

    // Deve contenere almeno una lettera
    if (!RegExp(r'[a-zA-ZàèéìòùÀÈÉÌÒÙ]').hasMatch(cleaned)) return false;

    return true;
  }

  bool isValidReferente(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return false;

    // Non solo simboli
    if (RegExp(r'^[\.\-_,;:!@#\$%\^&\*\(\)\+=\/\\\|\[\]\{\}]+$')
        .hasMatch(cleaned)) {
      return false;
    }

    // Deve contenere almeno una lettera
    if (!RegExp(r'[a-zA-ZàèéìòùÀÈÉÌÒÙ]').hasMatch(cleaned)) return false;

    return true;
  }

  bool isValidDescription(String text) {
    final cleaned = text.trim();

    if (cleaned.isEmpty) return false;

    // Non solo simboli
    if (RegExp(r'^[\.\-_,;:!@#\$%\^&\*\(\)\+=\/\\\|\[\]\{\}]+$')
        .hasMatch(cleaned)) {
      return false;
    }

    if (cleaned.length < 5) return false;

    return true;
  }

  bool get isFormValid =>
      isValidActivityName(activityNameController.text) &&
      isValidReferente(referenteController.text) &&
      isValidEmail(activityEmailController.text) &&
      isValidDescription(descriptionController.text);

  Future<void> submitSuggestion() async {
    if (!isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Compila correttamente tutti i campi")),
      );
      return;
    }

    setState(() => isSending = true);

    await Future.delayed(const Duration(seconds: 1));

    setState(() => isSending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Suggerimento inviato!")),
    );

    activityNameController.clear();
    referenteController.clear();
    activityEmailController.clear();
    descriptionController.clear();
    setState(() {});
  }

  Widget buildInputBox({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: "Suggerisci un'attività",
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildInputBox(
              label: "Nome dell'attività",
              controller: activityNameController,
            ),
            const SizedBox(height: 20),

            buildInputBox(
              label: "Referente",
              controller: referenteController,
            ),
            const SizedBox(height: 20),

            buildInputBox(
              label: "Email dell'attività",
              controller: activityEmailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            buildInputBox(
              label: "Perché la suggerisci?",
              controller: descriptionController,
              maxLines: 4,
            ),
            const SizedBox(height: 40),

            Center(
              child: GestureDetector(
                onTap: () {
                  if (isFormValid && !isSending) {
                    submitSuggestion();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Compila correttamente tutti i campi"),
                      ),
                    );
                  }
                },
                child: Opacity(
                  opacity: isFormValid && !isSending ? 1 : 0.4,
                  child: BlueNarrowButton(
                    label: isSending ? "Invio..." : "Invia suggerimento",
                    icon: Icons.send,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}