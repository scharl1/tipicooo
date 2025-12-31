import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Loader universale Tipicooo.
/// Quattro pallini che ruotano in modo fluido.
class LoaderWidget extends StatefulWidget {
  const LoaderWidget({super.key});

  @override
  State<LoaderWidget> createState() => _LoaderWidgetState();
}

class _LoaderWidgetState extends State<LoaderWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _size = 40;
  static const double _dotSize = 10;
  static const int _dotsCount = 4;
  static const double _quarterTurn = 1.57; // π/2

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RotationTransition(
        turns: _controller,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            children: List.generate(
              _dotsCount,
              (i) => Transform.rotate(
                angle: i * _quarterTurn,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: _dotSize,
                    height: _dotSize,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}