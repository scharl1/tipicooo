import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class PhotoPreview extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  final VoidCallback? onReplace;

  const PhotoPreview({
    super.key,
    required this.path,
    required this.onRemove,
    this.onReplace,
  });

  void _openPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    path,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _openPreview(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb
                ? Image.network(
                    path,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : const SizedBox.shrink(), // versione mobile la aggiungeremo dopo
          ),
        ),

        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),

        if (onReplace != null)
          Positioned(
            bottom: 6,
            right: 6,
            child: GestureDetector(
              onTap: onReplace,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }
}
