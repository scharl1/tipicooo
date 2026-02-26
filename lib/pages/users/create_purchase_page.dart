import 'package:flutter/material.dart';
import 'package:tipicooo/logiche/requests/purchase_service.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

class CreatePurchasePage extends StatefulWidget {
  const CreatePurchasePage({
    super.key,
    required this.activityRequestId,
    required this.activityTitle,
  });

  final String activityRequestId;
  final String activityTitle;

  @override
  State<CreatePurchasePage> createState() => _CreatePurchasePageState();
}

class _CreatePurchasePageState extends State<CreatePurchasePage> {
  final _amountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (widget.activityRequestId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Attività non valida. Riapri la scheda attività e riprova.",
          ),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final purchaseId = await PurchaseService.createPurchase(
      activityRequestId: widget.activityRequestId,
      totalEuroText: _amountController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (purchaseId == null) {
      final detail = (PurchaseService.lastCreatePurchaseError ?? "").trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail.isEmpty
                ? "Errore: importo non valido o richiesta non inviata."
                : detail,
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Richiesta inviata. In attesa di conferma dell'attività.",
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      scrollable: false,
      headerTitle: "Registra pagamento",
      showBack: true,
      showHome: true,
      showProfile: true,
      showBell: false,
      showLogout: false,
      body: AppBodyLayout(
        children: [
          Text(
            widget.activityTitle,
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            "Inserisci l'importo totale della spesa. L'attività dovrà confermare entro 24 ore.",
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Importo (EUR)",
              hintText: "Es. 12,50",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          BlueNarrowButton(
            label: _isSubmitting ? "Invio..." : "Invia richiesta",
            icon: Icons.send,
            onPressed: _isSubmitting ? () {} : _submit,
          ),
          if (_isSubmitting) ...[
            const SizedBox(height: 10),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
