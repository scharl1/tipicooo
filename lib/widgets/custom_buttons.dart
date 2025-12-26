import 'package:flutter/material.dart';
import 'package:tipicooo/theme/app_colors.dart';

/// 🔵 Pulsante blu originale (compatibilità)
class BlueNarrowButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const BlueNarrowButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// ⚪ Pulsante bianco arrotondato con ombra e testo blu
class RoundedYellowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const RoundedYellowButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryBlue,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
            side: BorderSide(
              color: AppColors.primaryBlue,
              width: 2,
            ),
          ),
        ),

        // ⭐ TESTO A SINISTRA — ICONA A DESTRA
        child: Row(
          children: [
            // Testo a sinistra
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(), // spinge l’icona a destra

            // Icona a destra
            Icon(icon, color: AppColors.primaryBlue),
          ],
        ),
      ),
    );
  }
}