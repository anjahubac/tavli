import 'package:material_ui/material_ui.dart';

import '../content/tavli_list.dart';
import '../controls/tavli_button.dart';
import '../controls/tavli_choice.dart';
import '../controls/tavli_icon_button.dart';
import '../controls/tavli_rows.dart';
import '../controls/tavli_taste_chips.dart';
import '../controls/tavli_text_field.dart';
import '../icons/tavli_icons.dart';
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
              GalleryLabeled(
                'Glavno · 48',
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
              GalleryLabeled(
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
              GalleryLabeled(
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
              GalleryLabeled(
                'U istom redu: iste visine (48)',
                TavliButtonRow(
                  expand: true,
                  children: [
                    TavliButton.primary(label: 'Kuvaj', onPressed: () {}),
                    TavliButton.secondary(label: 'Skuvano', onPressed: () {}),
                  ],
                ),
              ),
              gap,
              GalleryLabeled(
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
              TavliTextField(
                label: 'API ključ',
                initialValue: 'gsk_primer',
                obscureText: true,
                trailing: TavliIconButton(
                  icon: Icons.visibility_outlined,
                  semanticLabel: 'Prikaži',
                  onPressed: _noop,
                ),
              ),
              gap,
              TavliSearchField(hint: 'Pretraži recepte'),
            ],
          ),
        ),
        const GallerySection(title: 'Izbori', child: _ChoicesDemo()),
        const GallerySection(title: 'Redovi', child: _RowsDemo()),
        const GallerySection(title: 'Ukusi i alergeni', child: _TastesDemo()),
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
  Set<String> _meals = {'Ručak'};
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryLabeled(
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
        GalleryLabeled(
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
        gap,
        GalleryLabeled(
          'Segmentno · preko cele širine, sa ikonicama',
          TavliChoice<int>.segmented(
            expand: true,
            options: const [
              TavliOption(0, 'Svetla', glyph: TavliIcons.lightMode),
              TavliOption(1, 'Tamna', glyph: TavliIcons.darkMode),
              TavliOption(2, 'Kao sistem', glyph: TavliIcons.systemMode),
            ],
            selected: _mode,
            onChanged: (v) => setState(() => _mode = v),
          ),
        ),
        gap,
        GalleryLabeled(
          'Više izbora odjednom',
          TavliMultiChoice<String>(
            options: const [
              TavliOption('Doručak', 'Doručak'),
              TavliOption('Ručak', 'Ručak'),
              TavliOption('Večera', 'Večera'),
            ],
            selected: _meals,
            onChanged: (v) => setState(() => _meals = v),
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
    Widget group(List<Widget> rows) => TavliListGroup(children: rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryLabeled(
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
        GalleryLabeled(
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

class _TastesDemo extends StatefulWidget {
  const _TastesDemo();

  @override
  State<_TastesDemo> createState() => _TastesDemoState();
}

class _TastesDemoState extends State<_TastesDemo> {
  var _milk = true;
  var _eggs = false;
  final _kinds = {
    'Čorba ili supa': TavliLiking.like,
    'Testenina': TavliLiking.none,
    'Slatko': TavliLiking.dislike,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryLabeled(
          'Alergen · pilula 44, dodir 48',
          TavliChipWrap(
            children: [
              TavliToggleChip(
                label: 'Mleko',
                icon: TavliIcons.allergenMilk,
                selected: _milk,
                onChanged: (v) => setState(() => _milk = v),
              ),
              TavliToggleChip(
                label: 'Jaja',
                icon: TavliIcons.allergenEggs,
                selected: _eggs,
                onChanged: (v) => setState(() => _eggs = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: TavliSpacing.medium),
        GalleryLabeled(
          'Alergen · pločica (računar)',
          Row(
            spacing: TavliSpacing.small,
            children: [
              Expanded(
                child: TavliToggleChip.tile(
                  label: 'Mleko',
                  icon: TavliIcons.allergenMilk,
                  selected: _milk,
                  onChanged: (v) => setState(() => _milk = v),
                ),
              ),
              Expanded(
                child: TavliToggleChip.tile(
                  label: 'Jaja',
                  icon: TavliIcons.allergenEggs,
                  selected: _eggs,
                  onChanged: (v) => setState(() => _eggs = v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TavliSpacing.medium),
        GalleryLabeled(
          'Volim · Ne volim · bez izbora',
          TavliChipWrap(
            children: [
              for (final MapEntry(:key, :value) in _kinds.entries)
                TavliLikingChip(
                  label: key,
                  liking: value,
                  onChanged: (v) => setState(() => _kinds[key] = v),
                ),
            ],
          ),
        ),
        const SizedBox(height: TavliSpacing.medium),
        const GalleryLabeled(
          'Izabrane namirnice i dodavanje',
          TavliChipWrap(
            children: [
              TavliRemovableChip(
                label: 'Paradajz',
                liking: TavliLiking.like,
                onRemove: _noop,
              ),
              TavliRemovableChip(
                label: 'Cvekla',
                liking: TavliLiking.dislike,
                onRemove: _noop,
              ),
              TavliAddChip(label: 'Dodaj', onTap: _noop),
            ],
          ),
        ),
      ],
    );
  }
}

void _noop() {}
