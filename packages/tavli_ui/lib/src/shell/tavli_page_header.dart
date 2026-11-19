import 'package:material_ui/material_ui.dart';

import 'shell_parts.dart';

/// Zaglavlje ekrana: opcioni red iznad naslova (npr. datum), veliki naslov i
/// akcije desno.
///
/// Telefon: naslov 28, ekstra podebljan. Računar: naslov 26, a akcije
/// („Dodaj recept“, „Danas“, Nedelja i Mesec) stoje desno u istom redu.
/// Na telefonu iste akcije obično idu u `TavliActionBar`; zaglavlje
/// prikazuje sve što dobije, a ekran bira gde ih stavlja.
class TavliPageHeader extends StatelessWidget {
  const TavliPageHeader({
    super.key,
    required this.title,
    this.overline,
    this.actions = const [],
  });

  final String title;

  /// Tekst iznad naslova, npr. „Petak, 13. novembar“.
  final String? overline;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final size = desktop ? 26.0 : 28.0;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (overline != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              overline!,
              style: t.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.4,
                color: c.onSurfaceVariant,
              ),
            ),
          ),
        Semantics(
          header: true,
          child: Text(
            title,
            style: t.headlineMedium?.copyWith(
              fontSize: size,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.02 * size,
              color: c.onSurface,
            ),
          ),
        ),
      ],
    );
    if (actions.isEmpty) return heading;
    // Kao na platnu: naslov levo, akcije desno u istom redu. Tek kad red
    // nema mesta (uzak prozor, krupan tekst), akcije prelaze ispod naslova,
    // a ako ni same ne staju u red, ređaju se jedna ispod druge.
    return ConstrainedBox(
      // Cela širina (kao `width: 100%`), da akcije stoje uz desnu ivicu.
      constraints: const BoxConstraints(
        minWidth: double.infinity,
        minHeight: 48,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          heading,
          OverflowBar(
            spacing: 12,
            overflowSpacing: 12,
            overflowAlignment: OverflowBarAlignment.end,
            children: actions,
          ),
        ],
      ),
    );
  }
}
