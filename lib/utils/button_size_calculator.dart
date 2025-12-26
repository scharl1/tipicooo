import 'package:flutter/material.dart';

class ButtonSizeCalculator {
  static Size calculate(List<String> labels, BuildContext context) {
    double maxWidth = 0;
    double maxHeight = 0;

    // Limite massimo per evitare overflow
    final maxTextWidth = MediaQuery.of(context).size.width - 32;

    for (var text in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
      )..layout(maxWidth: maxTextWidth);

      if (painter.width > maxWidth) maxWidth = painter.width;
      if (painter.height > maxHeight) maxHeight = painter.height;
    }

    // Padding universale
    const horizontalPadding = 48.0;
    const verticalPadding = 32.0;

    // Larghezza minima per evitare i 76px su Web
    final minWidth = 200.0;

    return Size(
      (maxWidth + horizontalPadding).clamp(minWidth, double.infinity),
      maxHeight + verticalPadding,
    );
  }
}