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

class _AppBodyLayoutState extends State<AppBodyLayout> {
  /// Larghezza massima trovata tra tutti i pulsanti
  double _maxButtonWidth = 0;

  /// Chiavi per misurare i pulsanti
  final Map<Key, GlobalKey> _buttonKeys = {};

  @override
  void initState() {
    super.initState();

    /// Post‑frame callback sicura
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.microtask(_measureButtons); // ⭐ FIX
    });
  }

  /// ------------------------------------------------------------
  /// MISURA TUTTI I PULSANTI DELLA PAGINA
  /// ------------------------------------------------------------
  void _measureButtons() {
    double maxWidth = 0;

    for (final entry in _buttonKeys.entries) {
      final key = entry.value;
      final context = key.currentContext;

      if (context == null) continue;

      final renderBox = context.findRenderObject() as RenderBox?;

      /// ⭐ FIX: evita crash se il widget non ha ancora una size
      if (renderBox == null || !renderBox.hasSize) continue;

      final width = renderBox.size.width;
      if (width > maxWidth) maxWidth = width;
    }

    if (maxWidth != _maxButtonWidth) {
      setState(() {
        _maxButtonWidth = maxWidth;
      });
    }
  }

  /// ------------------------------------------------------------
  /// RICONOSCE SE UN WIDGET È UN PULSANTE
  /// ------------------------------------------------------------
  bool _isButton(Widget w) {
    return w.runtimeType.toString().contains("Button");
  }

  /// ------------------------------------------------------------
  /// WRAP AUTOMATICO DEI PULSANTI CON GLOBALKEY
  /// ------------------------------------------------------------
  Widget _wrapForMeasurement(Widget child) {
    if (!_isButton(child)) return child;

    final key = GlobalKey();
    _buttonKeys[child.key ?? UniqueKey()] = key;

    return Container(
      key: key,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: _maxButtonWidth > 0 ? _maxButtonWidth : 0,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),

      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.maxContentWidth,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,

            /// Applichiamo spacing + wrapping pulsanti
            children: _buildSpacedChildren(),
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
      spaced.add(_wrapForMeasurement(widget.children[i]));

      if (i < widget.children.length - 1) {
        spaced.add(SizedBox(height: widget.verticalSpacing));
      }
    }

    return spaced;
  }
}