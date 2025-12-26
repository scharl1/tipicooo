import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/theme/app_colors.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: "Test",
      showBack: true,
      showHome: false,
      showBell: false,
      bottomNavigationBar: null,

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            _BlueNarrowButton(label: "1. Narrow Elegante", icon: Icons.star, onPressed: () {}),

            _RoundedButton(label: "2. Arrotondato", icon: Icons.favorite, onPressed: () {}),

            _OutlineButton(label: "3. Outline", icon: Icons.circle_outlined, onPressed: () {}),

            _ShadowButton(label: "4. Ombra Forte", icon: Icons.flash_on, onPressed: () {}),

            _FlatMinimalButton(label: "5. Minimal Flat", icon: Icons.remove, onPressed: () {}),

            _GradientButton(label: "6. Gradiente", icon: Icons.gradient, onPressed: () {}),

            _GlassButton(label: "7. Vetro", icon: Icons.blur_on, onPressed: () {}),

            _IconOnlyButton(icon: Icons.settings, onPressed: () {}),

            _BigCardButton(label: "9. Card Grande", icon: Icons.dashboard, onPressed: () {}),

            _DangerButton(label: "10. Danger", icon: Icons.warning, onPressed: () {}),
          ],
        ),
      ),
    );
  }
}

//
// 1 — Pulsante elegante (quello che già usi)
//
class _BlueNarrowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _BlueNarrowButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(width: 14),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              ]),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

//
// 2 — Arrotondato pieno
//
class _RoundedButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundedButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 30),
        ),
        onPressed: onPressed,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
        ]),
      ),
    );
  }
}

//
// 3 — Outline
//
class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _OutlineButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.blue, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 30),
        ),
        onPressed: onPressed,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.blue, fontSize: 18)),
        ]),
      ),
    );
  }
}

//
// 4 — Ombra forte
//
class _ShadowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ShadowButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
          decoration: BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.deepOrange.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
          ]),
        ),
      ),
    );
  }
}

//
// 5 — Minimal flat
//
class _FlatMinimalButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _FlatMinimalButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      TextButton(
        onPressed: onPressed,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.black),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.black, fontSize: 18)),
        ]),
      ),
    );
  }
}

//
// 6 — Gradiente
//
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _GradientButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.blue, Colors.purple]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
          ]),
        ),
      ),
    );
  }
}

//
// 7 — Effetto vetro
//
class _GlassButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
        ]),
      ),
    );
  }
}

//
// 8 — Icona sola
//
class _IconOnlyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _IconOnlyButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

//
// 9 — Card grande
//
class _BigCardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _BigCardButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      InkWell(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 20),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 20)),
          ]),
        ),
      ),
    );
  }
}

//
// 10 — Danger rosso
//
class _DangerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _DangerButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
          ]),
        ),
      ),
    );
  }
}

//
// Wrapper per spacing uniforme
//
Widget _wrap(Widget child) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: child,
  );
}