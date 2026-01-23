import 'package:flutter/material.dart';
import 'package:tipicooo/theme/app_text_styles.dart';

class ActivityTypeDynamicSelector extends StatefulWidget {
  final String? selectedType;
  final Function(String) onSelected;
  final String? errorText;

  const ActivityTypeDynamicSelector({
    super.key,
    required this.selectedType,
    required this.onSelected,
    this.errorText,
  });

  @override
  State<ActivityTypeDynamicSelector> createState() =>
      _ActivityTypeDynamicSelectorState();
}

class _ActivityTypeDynamicSelectorState
    extends State<ActivityTypeDynamicSelector> {
  final TextEditingController newTypeController = TextEditingController();

  // ⭐ Lista dinamica delle tipologie
  List<String> types = [];

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Tipologia attività", style: AppTextStyles.labelStyle),
        const SizedBox(height: 6),

        // ⭐ Dropdown dinamico
        DropdownButtonFormField<String>(
          initialValue: widget.selectedType,
          items: types
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (value) {
            widget.onSelected(value!);
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            errorText: hasError ? widget.errorText : null,
          ),
          hint: const Text("Seleziona tipologia"),
        ),

        const SizedBox(height: 12),

        // ⭐ Campo per aggiungere una nuova tipologia
        TextField(
          controller: newTypeController,
          decoration: InputDecoration(
            labelText: "Inserisci nuova tipologia",
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 8),

        // ⭐ Pulsante per aggiungere la tipologia
        ElevatedButton(
          onPressed: () {
            final newType = newTypeController.text.trim();
            if (newType.isEmpty) return;

            setState(() {
              types.add(newType);
            });

            widget.onSelected(newType);
            newTypeController.clear();
          },
          child: const Text("Aggiungi tipologia"),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}