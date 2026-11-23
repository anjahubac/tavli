import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/home_shell.dart' show wideLayoutWidth;

/// Kostur koraka pravljenja plana (podešavanje, predlog), kao ekrani
/// Profila: na telefonu gornja traka sa povratkom i naslovom, na širokom
/// ekranu povratak i veliki naslov na vrhu sadržaja. Sadržaj je čitljive
/// širine ([TavliWidth.readable]).
class PlanStepPage extends StatelessWidget {
  const PlanStepPage({
    super.key,
    required this.title,
    required this.onBack,
    required this.children,
    this.backLabel = 'Plan',
    this.bottom,
    this.maxWidth = TavliWidth.readable,
  });

  final String title;
  final VoidCallback onBack;

  /// Naziv prethodnog ekrana (iOS traka i povratak na širokom ekranu).
  final String backLabel;
  final List<Widget> children;

  /// Traka sa akcijama zakucana ispod sadržaja koji se pomera.
  final Widget? bottom;

  /// Najveća širina sadržaja na širokom ekranu.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!wide)
            TavliBackAppBar(title: title, onBack: onBack, backLabel: backLabel),
          Expanded(
            child: SafeArea(
              top: wide,
              bottom: bottom == null,
              child: TavliPage(
                wide: wide,
                maxWidth: maxWidth,
                children: [
                  if (wide)
                    TavliPageHeader(
                      title: title,
                      backLabel: backLabel,
                      onBack: onBack,
                    ),
                  ...children,
                ],
              ),
            ),
          ),
          if (bottom case final bar?) SafeArea(top: false, child: bar),
        ],
      ),
    );
  }
}
