import 'package:material_ui/material_ui.dart';

import '../theme/tavli_colors.dart';
import '../tokens.dart';

/// Zakucana traka sa akcijama na dnu ekrana, odmah iznad navigacije
/// („Ponovo predloži“ i „Otvori nabavku“, „Prebaci u ostavu (2)“).
///
/// Dugmad dele širinu podjednako. Traka se stavlja ispod sadržaja koji se
/// pomera (npr. `Column(children: [Expanded(sadržaj), TavliActionBar(…)])`),
/// pa ostaje na istom mestu kada se sadržaj promeni (Nedelja i Mesec).
/// Na računaru iste akcije idu u `TavliPageHeader`.
///
/// Dugmad u traci su uvek visine 56 (i sporedno, da budu iste visine kao
/// glavno), sa manjim unutrašnjim razmakom i tekstom 15, da „Ponovo
/// predloži“ i „Otvori nabavku“ stanu u jedan red na telefonu.
class TavliActionBar extends StatelessWidget {
  const TavliActionBar({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final x = TavliColors.of(context);
    final theme = Theme.of(context);
    final inBar = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: inBar.merge(theme.filledButtonTheme.style),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: inBar.merge(theme.outlinedButtonTheme.style),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: x.bg,
          border: Border(top: BorderSide(color: x.line)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TavliSpacing.large,
            vertical: TavliSpacing.small,
          ),
          child: Row(
            children: [
              for (final (i, a) in actions.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: a),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
