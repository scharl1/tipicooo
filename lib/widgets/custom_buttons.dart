import 'package:flutter/material.dart';
import 'package:tipicooo/theme/app_colors.dart';

/// ------------------------------------------------------------
/// REGOLE UNIVERSALI TIPICOOO PER I PULSANTI
/// ------------------------------------------------------------
/// 1. Autosizing totale: nessuna height/width fissa.
/// 2. Il testo può andare su 2 righe ed è SEMPRE allineato a sinistra.
/// 3. L’icona è SEMPRE a destra.
/// 4. Tutti i pulsanti della pagina devono avere la stessa
///    dimensione: il più grande determina la misura.
/// 5. Padding universale: vertical 16, horizontal 22.
/// 6. Tipografia universale: fontSize 18, fontWeight w600.
/// 7. Nessuna logica nei pulsanti: solo UI.
/// ------------------------------------------------------------

/// 🔵 Pulsante blu universale (autosizing, coerente)
class BlueNarrowButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const BlueNarrowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Flexible(
      child: Text(
        label,
        maxLines: 2,
        softWrap: true,
        textAlign: TextAlign.left,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    if (icon != null) ...[
      const SizedBox(width: 12),
      Icon(icon, color: Colors.white),
    ],
  ],
),
      ),
    );
  }
}

/// ⚪ Pulsante bianco arrotondato con bordo blu e icona a destra
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
           color: Colors.black.withValues(alpha: 0.15),
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
            horizontal: 22,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
            side: BorderSide(
              color: AppColors.primaryBlue,
              width: 2,
            ),
          ),
        ),

        child: Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Flexible(
      child: Text(
        label,
        maxLines: 2,
        softWrap: true,
        textAlign: TextAlign.left,
        style: const TextStyle(
          color: AppColors.primaryBlue,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    const SizedBox(width: 12),
    Icon(icon, color: AppColors.primaryBlue),
  ],
),
      ),
    );
  }
}

/// 🔴 Pulsante Danger (per eliminare, azioni distruttive)
class DangerButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const DangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.red.shade900.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Flexible(
      child: Text(
        label,
        maxLines: 2,
        softWrap: true,
        textAlign: TextAlign.left,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    if (icon != null) ...[
      const SizedBox(width: 12),
      Icon(icon, color: Colors.white),
    ],
  ],
),
      ),
    );
  }
}