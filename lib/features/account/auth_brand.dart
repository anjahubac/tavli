import 'package:material_ui/material_ui.dart';

/// Znak iznad naslova u toku prijave i pri prvom podešavanju naloga.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  // Kanvas: znak 48.
  static const _size = 48.0;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Image.asset(
      'assets/branding/tavli-auth-icon.png',
      width: _size,
      height: _size,
      fit: BoxFit.contain,
      semanticLabel: 'Tavli',
    ),
  );
}
