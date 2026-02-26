import 'package:flutter/material.dart';
import 'package:tipicooo/theme/app_colors.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

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
  final Color? color;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;

  const BlueNarrowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primaryBlue;
    final fg = foregroundColor ?? Colors.white;
    return _UniformButtonWidthWrapper(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _ButtonLabelRow(
            label: label,
            color: fg,
            icon: icon,
          ),
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
    return _UniformButtonWidthWrapper(
      child: Container(
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
          child: _ButtonLabelRow(
            label: label,
            color: AppColors.primaryBlue,
            icon: icon,
          ),
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
    return _UniformButtonWidthWrapper(
      child: InkWell(
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
          child: _ButtonLabelRow(
            label: label,
            color: Colors.white,
            icon: icon,
          ),
        ),
      ),
    );
  }
}

class _ButtonLabelRow extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _ButtonLabelRow({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 2,
              softWrap: true,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (icon != null) ...[
          const SizedBox(width: 12),
          Icon(icon, color: color),
        ],
      ],
    );
  }
}

class _UniformButtonWidthWrapper extends StatefulWidget {
  final Widget child;

  const _UniformButtonWidthWrapper({required this.child});

  @override
  State<_UniformButtonWidthWrapper> createState() =>
      _UniformButtonWidthWrapperState();
}

class _UniformButtonWidthWrapperState extends State<_UniformButtonWidthWrapper> {
  final GlobalKey _measureKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportWidth());
  }

  void _reportWidth() {
    if (!mounted) return;
    final scope = UniformButtonWidthScope.maybeOf(context);
    if (scope == null) return;
    final ctx = _measureKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    scope.reportWidth(box.size.width);
  }

  @override
  Widget build(BuildContext context) {
    final scope = UniformButtonWidthScope.maybeOf(context);
    final minWidth = scope?.maxWidth ?? 0;

    return ConstrainedBox(
      key: _measureKey,
      constraints: BoxConstraints(minWidth: minWidth),
      child: widget.child,
    );
  }
}
