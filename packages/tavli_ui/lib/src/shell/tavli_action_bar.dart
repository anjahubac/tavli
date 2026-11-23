import 'package:material_ui/material_ui.dart';

import '../controls/tavli_button.dart';
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
/// Dugmad u traci su visine 48 (glavno i sporedno isto), sa manjim unutrašnjim razmakom i tekstom 15, da „Ponovo
/// predloži“ i „Otvori nabavku“ stanu u jedan red na telefonu.
class TavliActionBar extends StatelessWidget {
  const TavliActionBar({super.key, required this.actions, this.note});

  final List<TavliButton> actions;

  /// Kratak tekst ispod dugmadi, u sredini (npr. „14 obroka · 2 porcije po
  /// obroku“ ispod „Predloži plan“).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final x = TavliColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: x.bg,
        border: Border(top: BorderSide(color: x.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TavliSpacing.large,
          vertical: TavliSpacing.small,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TavliSpacing.small - 2,
          children: [
            TavliButtonScope.actionBar(
              child: TavliButtonRow(expand: true, children: actions),
            ),
            if (note case final text?)
              Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
