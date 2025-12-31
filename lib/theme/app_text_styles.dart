import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ------------------------------------------------------------
/// APP TEXT STYLES — TIPOGRAFIA UNIVERSALE TIPICOOO
/// ------------------------------------------------------------
/// Tutte le regole tipografiche condivise.
/// Ogni pagina deve usare questi stili.
/// ------------------------------------------------------------
class AppTextStyles {
  /// Messaggi centrali delle pagine (Search, Favorites, Profile, ecc.)
  static const pageMessage = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.black,
  );

  /// Titoli di sezioni interne (se servono in futuro)
  static const sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.black,
  );

  /// Testo normale
  static const body = TextStyle(
    fontSize: 16,
    color: AppColors.black,
  );
}