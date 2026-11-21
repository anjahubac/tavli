import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

/// Znak iznad naslova u toku prijave i pri prvom podešavanju naloga.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Image.asset(
      'assets/branding/tavli-auth-icon.png',
      width: TavliSpacing.large * 2,
      semanticLabel: 'Tavli',
    ),
  );
}
