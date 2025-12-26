import 'package:flutter/material.dart';
import 'package:tipicooo/theme/app_colors.dart';

/// Campo di testo standard dell’app.
/// Riutilizzabile ovunque per mantenere stile coerente.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final bool autofocus; // 👈 AGGIUNTO

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.autofocus = false, // 👈 AGGIUNTO
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autofocus: autofocus, // 👈 AGGIUNTO
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.bold,
        ),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryBlue),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
      ),
    );
  }
}