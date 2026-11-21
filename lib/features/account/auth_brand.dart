import 'package:material_ui/material_ui.dart';

/// Znak iznad naslova u toku prijave i pri prvom podešavanju naloga.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Image.asset(
      'assets/branding/tavli-auth-icon.png',
      // Kanvas: znak 48.
      width: 48,
      semanticLabel: 'Tavli',
    ),
  );
}
