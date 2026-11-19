import 'package:material_ui/material_ui.dart';

import '../controls/tavli_button.dart';
import '../controls/tavli_choice.dart';
import '../controls/tavli_icon_button.dart';
import '../controls/tavli_rows.dart';
import '../controls/tavli_text_field.dart';
import '../theme/tavli_colors.dart';
import '../tokens.dart';
import 'gallery_section.dart';

/// Odeljci galerije za dugmad, polja i izbore.
class TavliControlsGallerySections extends StatelessWidget {
  const TavliControlsGallerySections({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GallerySection(
          title: 'Dugmad',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Labeled(
                'Glavno · 56',
                Wrap(
                  spacing: TavliSpacing.small,
                  runSpacing: TavliSpacing.small,
                  children: [
                    TavliButton.primary(label: 'Sačuvaj', onPressed: () {}),
                    TavliButton.primary(
                      label: 'Dodaj recept',
                      icon: Icons.add,
                      onPressed: () {},
                    ),
                    const TavliButton.primary(
                      label: 'Isključeno',
                      onPressed: null,
                    ),
                  ],
                ),
              ),
              gap,
              _Labeled(
                'Sporedno · 48',
                Wrap(
                  spacing: TavliSpacing.small,
                  runSpacing: TavliSpacing.small,
                  children: [
                    TavliButton.secondary(label: 'Otkaži', onPressed: () {}),
                    TavliButton.secondary(
                      label: 'Danas',
                      icon: Icons.today_outlined,
                      onPressed: () {},
                    ),
                    const TavliButton.secondary(
                      label: 'Isključeno',
                      onPressed: null,
                    ),
                  ],
                ),
              ),
              gap,
              _Labeled(
                'Tekstualno i za brisanje · 48',
                Wrap(
                  spacing: TavliSpacing.small,
                  runSpacing: TavliSpacing.small,
                  children: [
                    TavliButton.text(label: 'Preskoči', onPressed: () {}),
                    TavliButton.text(
                      label: 'Izmeni',
                      icon: Icons.edit_outlined,
                      onPressed: () {},
                    ),
                    TavliButton.destructive(
                      label: 'Obriši ceo dnevnik ishrane',
                      icon: Icons.delete_outline,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              gap,
              _Labeled(
                'U istom redu: iste visine (56)',
                TavliButtonRow(
                  expand: true,
                  children: [
                    TavliButton.primary(label: 'Kuvaj', onPressed: () {}),
                    TavliButton.secondary(label: 'Skuvano', onPressed: () {}),
                  ],
                ),
              ),
              gap,
              _Labeled(
                'Sa ikonicom (opis je obavezan)',
                Wrap(
                  children: [
                    TavliIconButton(
                      icon: Icons.edit_outlined,
                      semanticLabel: 'Izmeni recept',
                      onPressed: () {},
                    ),
                    TavliIconButton(
                      icon: Icons.favorite,
                      semanticLabel: 'Omiljeni recept',
                      selected: true,
                      onPressed: () {},
                    ),
                    TavliIconButton(
                      icon: Icons.more_vert,
                      semanticLabel: 'Još opcija',
                      onPressed: () {},
                    ),
                    const TavliIconButton(
                      icon: Icons.delete_outline,
                      semanticLabel: 'Obriši',
                      onPressed: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const GallerySection(
          title: 'Polja',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TavliTextField(label: 'Naziv recepta', hint: 'npr. Sarma'),
              gap,
              TavliTextField(
                label: 'Količina',
                initialValue: 'pola',
                errorText: 'Unesi broj, npr. 1,5',
              ),
              gap,
              TavliTextField(
                label: 'Porcije',
                initialValue: '4',
                enabled: false,
              ),
              gap,
              TavliSearchField(hint: 'Pretraži recepte'),
            ],
          ),
        ),
        const GallerySection(title: 'Izbori', child: _ChoicesDemo()),
        const GallerySection(title: 'Redovi', child: _RowsDemo()),
      ],
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: t.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: TavliSpacing.small),
        child,
      ],
    );
  }
}

class _ChoicesDemo extends StatefulWidget {
  const _ChoicesDemo();

  @override
  State<_ChoicesDemo> createState() => _ChoicesDemoState();
}

enum _Shopping { plan, recipe }

class _ChoicesDemoState extends State<_ChoicesDemo> {
  bool _month = false;
  _Shopping _shopping = _Shopping.plan;
  int _week = 1;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Labeled(
          'Segmentno · fiksne širine',
          TavliChoice<bool>.segmented(
            options: const [
              TavliOption(false, 'Nedelja'),
              TavliOption(true, 'Mesec'),
            ],
            selected: _month,
            onChanged: (v) => setState(() => _month = v),
          ),
        ),
        gap,
        TavliChoice<_Shopping>.segmented(
          options: const [
            TavliOption(_Shopping.plan, 'Po planu'),
            TavliOption(_Shopping.recipe, 'Po receptu'),
          ],
          selected: _shopping,
          onChanged: (v) => setState(() => _shopping = v),
        ),
        gap,
        _Labeled(
          'Čipovi za filter',
          TavliChoice<int>.chips(
            options: const [
              TavliOption(1, 'Nedelja 1'),
              TavliOption(2, 'Nedelja 2'),
              TavliOption(0, 'Ceo plan'),
            ],
            selected: _week,
            onChanged: (v) => setState(() => _week = v),
          ),
        ),
      ],
    );
  }
}

class _RowsDemo extends StatefulWidget {
  const _RowsDemo();

  @override
  State<_RowsDemo> createState() => _RowsDemoState();
}

class _RowsDemoState extends State<_RowsDemo> {
  final _bought = {'Paradajz': false, 'Pirinač': true};
  bool _hideNumbers = false;
  bool _sync = true;

  @override
  Widget build(BuildContext context) {
    final x = TavliColors.of(context);
    final divider = Divider(height: 1, color: x.line);
    Widget group(List<Widget> rows) => DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(TavliRadius.field),
        border: Border.all(color: x.line),
      ),
      child: Column(
        children: [
          for (final (i, r) in rows.indexed) ...[if (i > 0) divider, r],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Labeled(
          'Sa štikliranjem · kupljeno precrtano',
          group([
            for (final e in _bought.entries)
              TavliCheckRow(
                title: e.key,
                detail: e.key == 'Paradajz' ? '1,5 kg' : '500 g',
                checked: e.value,
                onChanged: (v) => setState(() => _bought[e.key] = v),
              ),
            const TavliCheckRow(
              title: 'Isključeno',
              checked: false,
              onChanged: null,
            ),
          ]),
        ),
        const SizedBox(height: TavliSpacing.medium),
        _Labeled(
          'Sa prekidačem',
          group([
            TavliSwitchRow(
              title: 'Sakrij brojeve u planu',
              subtitle: 'Kalorije se ne prikazuju na karticama obroka',
              value: _hideNumbers,
              onChanged: (v) => setState(() => _hideNumbers = v),
            ),
            TavliSwitchRow(
              title: 'Sinhronizuj fotografije',
              value: _sync,
              onChanged: (v) => setState(() => _sync = v),
            ),
          ]),
        ),
      ],
    );
  }
}
