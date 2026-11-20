import 'package:material_ui/material_ui.dart';

import '../theme/tavli_status_colors.dart';

/// Oznaka stanja: krug 18. Za sada jedna varijanta, skuvano (zelena
/// kvačica).
class TavliTag extends StatelessWidget {
  /// Skuvan obrok. Čitač ekrana kaže „Skuvano“.
  const TavliTag.cooked({super.key, this.semanticLabel = 'Skuvano'});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tone = TavliStatusColors.of(context).success;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tone.foreground,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 13, color: tone.background),
        ),
      ),
    );
  }
}
