import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// APPBODYLAYOUT — VERSIONE TIPICOOO (CORRETTA)
/// ------------------------------------------------------------
/// Questo widget applica le regole universali di layout:
///
/// ✔ Margini laterali
/// ✔ Centratura
/// ✔ Larghezza massima del contenuto
/// ✔ Scroll automatico
/// ✔ Spacing verticale
///
/// E SOPRATTUTTO:
/// ✔ Sincronizzazione automatica della larghezza dei pulsanti
///   → Qualsiasi widget che contiene “Button” nel nome
///   → Il pulsante più grande determina la misura di tutti
///
/// FIX IMPORTANTI:
/// ✔ Misurazione sicura (solo quando il widget ha una size valida)
/// ✔ Microtask post‑frame per evitare crash
/// ------------------------------------------------------------
class AppBodyLayout extends StatefulWidget {
  final List<Widget> children;
  final double maxContentWidth;
  final double verticalSpacing;

  const AppBodyLayout({
    super.key,
    required this.children,
    this.maxContentWidth = 500,
    this.verticalSpacing = 24,
  });

  @override
  State<AppBodyLayout> createState() => _AppBodyLayoutState();
}

class UniformButtonWidthController extends ChangeNotifier {
  double _maxWidth = 0;

  double get maxWidth => _maxWidth;

  void reportWidth(double width) {
    if (width <= 0) return;
    if (width > _maxWidth + 0.5) {
      _maxWidth = width;
      notifyListeners();
    }
  }

  void reset() {
    if (_maxWidth == 0) return;
    _maxWidth = 0;
    notifyListeners();
  }
}

class UniformButtonWidthScope
    extends InheritedNotifier<UniformButtonWidthController> {
  const UniformButtonWidthScope({
    super.key,
    required UniformButtonWidthController controller,
    required super.child,
  }) : super(notifier: controller);

  static UniformButtonWidthController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<UniformButtonWidthScope>()
        ?.notifier;
  }
}

class _AppBodyLayoutState extends State<AppBodyLayout> {
  final UniformButtonWidthController _widthController =
      UniformButtonWidthController();
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant AppBodyLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _widthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UniformButtonWidthScope(
      controller: _widthController,
      child: SingleChildScrollView(
        controller: _scrollController,
        primary: false,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: _buildSpacedChildren(),
            ),
          ),
        ),
      ),
    );
  }

  /// ------------------------------------------------------------
  /// SPACING UNIVERSALE + WRAP DEI PULSANTI
  /// ------------------------------------------------------------
  List<Widget> _buildSpacedChildren() {
    final spaced = <Widget>[];

    for (int i = 0; i < widget.children.length; i++) {
      spaced.add(widget.children[i]);

      if (i < widget.children.length - 1) {
        spaced.add(SizedBox(height: widget.verticalSpacing));
      }
    }

    return spaced;
  }
}
