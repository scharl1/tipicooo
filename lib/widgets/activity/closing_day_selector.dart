import 'package:flutter/material.dart';
import 'package:tipicooo/theme/app_text_styles.dart';

class ClosingDaySelector extends StatelessWidget {
  final String? selectedDay;
  final Function(String) onSelected;
  final String? errorText;

  const ClosingDaySelector({
    super.key,
    required this.selectedDay,
    required this.onSelected,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;

    final days = const [
      "Lunedì",
      "Martedì",
      "Mercoledì",
      "Giovedì",
      "Venerdì",
      "Sabato",
      "Domenica",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Giorno di chiusura",
          style: AppTextStyles.labelStyle,
        ),
        const SizedBox(height: 6),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: days.map((day) {
            final isSelected = selectedDay == day;

            return GestureDetector(
              onTap: () => onSelected(day),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasError
                        ? Colors.red
                        : (isSelected ? Colors.blue : Colors.grey.shade400),
                    width: hasError ? 2 : 1.2,
                  ),
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              errorText!,
              style: AppTextStyles.errorStyle,
            ),
          ),

        const SizedBox(height: 16),
      ],
    );
  }
}