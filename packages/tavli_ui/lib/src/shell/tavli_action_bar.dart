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
  const TavliActionBar({super.key, required this.actions});

  final List<TavliButton> actions;

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
        child: TavliButtonScope.actionBar(
          child: TavliButtonRow(expand: true, children: actions),
        ),
      ),
    );
  }
}
