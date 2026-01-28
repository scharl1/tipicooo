import 'package:flutter/material.dart';

class AddPhotoBox extends StatelessWidget {
  final VoidCallback onTap;

  const AddPhotoBox({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,   // ⭐ FIX OVERFLOW
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 32, color: Colors.blue),
              SizedBox(height: 6),
              Text("Aggiungi foto"),
            ],
          ),
        ),
      ),
    );
  }
}