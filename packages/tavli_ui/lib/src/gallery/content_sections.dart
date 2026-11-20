import 'package:material_ui/material_ui.dart';

import '../content/tavli_card.dart';
import '../content/tavli_data_table.dart';
import '../content/tavli_list.dart';
import '../content/tavli_media.dart';
import '../content/tavli_notice.dart';
import '../content/tavli_states.dart';
import '../content/tavli_tag.dart';
import '../controls/tavli_button.dart';
import '../controls/tavli_rows.dart';
import '../tokens.dart';
import 'gallery_section.dart';

/// Odeljci galerije za kartice, liste, napomene i stanja ekrana.
class TavliContentGallerySections extends StatelessWidget {
  const TavliContentGallerySections({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GallerySection(title: 'Kartice', child: _Cards()),
        GallerySection(title: 'Liste', child: _Lists()),
        GallerySection(title: 'Tabela za računar', child: _Table()),
        GallerySection(
          title: 'Napomene',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TavliNotice(
                message: 'Plan se pravi od recepata iz tvoje kolekcije.',
              ),
              gap,
              _WarningNotice(),
              gap,
              TavliNotice(
                tone: TavliNoticeTone.success,
                message: 'Namirnice su prebačene u ostavu.',
              ),
              gap,
              TavliNotice(
                tone: TavliNoticeTone.error,
                title: 'Recept nije napravljen',
                message: 'Svi AI modeli su trenutno zauzeti. Probaj ponovo.',
              ),
            ],
          ),
        ),
        GallerySection(title: 'Naslov odeljka', child: _Headers()),
        GallerySection(title: 'Sličica, avatar i oznaka', child: _Media()),
        GallerySection(title: 'Prazan ekran i učitavanje', child: _States()),
      ],
    );
  }
}

class _WarningNotice extends StatelessWidget {
  const _WarningNotice();

  @override
  Widget build(BuildContext context) => TavliNotice(
    tone: TavliNoticeTone.warning,
    message: 'Za sutrašnji ručak fale 2 namirnice.',
    linkLabel: 'Nabavka',
    onLink: () {},
  );
}

class _MealCard extends StatelessWidget {
  const _MealCard(this.slot, this.name, this.variant, {this.extra});

  final String slot;
  final String name;
  final TavliCardVariant variant;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = variant == TavliCardVariant.highlighted
        ? null
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final compact = variant == TavliCardVariant.compact;
    return TavliCard(
      variant: variant,
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot,
            style: t.labelMedium?.copyWith(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: t.titleMedium?.copyWith(
              fontSize: compact ? 13 : 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 4),
            Text(
              extra!,
              style: t.bodySmall?.copyWith(fontSize: 13, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards();

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryLabeled(
          'Obična, istaknuta i skuvana · iste visine u redu',
          TavliCardRow(
            children: [
              _MealCard('Doručak', 'Ovsena kaša', TavliCardVariant.cooked),
              _MealCard(
                'Ručak · sledeći',
                'Piletina sa povrćem iz rerne',
                TavliCardVariant.highlighted,
                extra: '45 min',
              ),
              _MealCard('Večera', 'Čorba', TavliCardVariant.plain),
            ],
          ),
        ),
        gap,
        GalleryLabeled(
          'Kompaktna · radijus 14',
          TavliCardRow(
            spacing: 6,
            children: [
              _MealCard('Pon', 'Sarma', TavliCardVariant.compact),
              _MealCard('Uto', 'Musaka od tikvica', TavliCardVariant.compact),
              _MealCard('Sre', 'Pasulj', TavliCardVariant.compact),
              _MealCard('Čet', 'Riba', TavliCardVariant.compact),
            ],
          ),
        ),
      ],
    );
  }
}

class _Lists extends StatefulWidget {
  const _Lists();

  @override
  State<_Lists> createState() => _ListsState();
}

class _ListsState extends State<_Lists> {
  final _pantry = ['Brašno', 'Jaja', 'So', 'Maslinovo ulje'];
  final _amounts = {'Brašno': '1 kg', 'Jaja': '10 kom', 'Maslinovo ulje': ''};
  final _bought = {'Paradajz': false, 'Luk': false};

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryLabeled(
          'Sa količinom (bez količine samo naziv) · prevuci ulevo za „Ukloni“',
          TavliListGroup(
            children: [
              for (final item in _pantry)
                TavliListRow(
                  key: ValueKey(item),
                  title: item,
                  quantity: _amounts[item],
                  onRemove: () => setState(() => _pantry.remove(item)),
                ),
            ],
          ),
        ),
        gap,
        GalleryLabeled(
          'Sa sličicom i strelicom',
          TavliListGroup(
            children: [
              TavliListRow(
                leading: const TavliThumbnail.row(),
                title: 'Sarma',
                subtitle: '2 h · 6 porcija',
                showChevron: true,
                onTap: () {},
              ),
              TavliListRow(
                leading: const TavliThumbnail.row(tintIndex: 1),
                title: 'Gibanica',
                subtitle: '1 h 10 min · 8 porcija',
                showChevron: true,
                onTap: () {},
              ),
            ],
          ),
        ),
        gap,
        GalleryLabeled(
          'Grupisana lista sa naslovima odeljaka',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TavliSectionHeader('Povrće'),
              TavliListGroup(
                children: [
                  for (final e in _bought.entries)
                    TavliCheckRow(
                      title: e.key,
                      detail: '1 kg',
                      checked: e.value,
                      onChanged: (v) => setState(() => _bought[e.key] = v),
                    ),
                ],
              ),
              const TavliSectionHeader(
                'Kupljeno · 1',
                style: TavliSectionHeaderStyle.bold,
              ),
              TavliListGroup(
                children: [
                  TavliCheckRow(
                    title: 'Pirinač',
                    detail: '500 g',
                    checked: true,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table();

  @override
  Widget build(BuildContext context) {
    return GalleryLabeled(
      '4 namirnice',
      TavliDataTable(
        columns: const [
          TavliColumn('Namirnica', flex: 3),
          TavliColumn('Količina', flex: 2, alignEnd: true),
        ],
        rows: [
          TavliTableRow(const ['Brašno', '1 kg'], onTap: () {}),
          TavliTableRow(const ['Jaja', '10 kom'], onTap: () {}),
          TavliTableRow(const ['So', ''], onTap: () {}),
          TavliTableRow(const ['Maslinovo ulje', '0,5 l'], onTap: () {}),
        ],
      ),
    );
  }
}

class _Headers extends StatelessWidget {
  const _Headers();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TavliSectionHeader('Na umu'),
        TavliSectionHeader(
          'Sutra',
          trailing: TavliButton.text(label: 'Prikaži plan', onPressed: () {}),
        ),
        const TavliSectionHeader(
          'Kupljeno · 2',
          style: TavliSectionHeaderStyle.bold,
        ),
      ],
    );
  }
}

class _Media extends StatelessWidget {
  const _Media();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryLabeled(
          'Sličica 56 · tri meke boje',
          Row(
            spacing: TavliSpacing.small,
            children: [
              TavliThumbnail.row(),
              TavliThumbnail.row(tintIndex: 1, icon: Icons.bakery_dining),
              TavliThumbnail.row(tintIndex: 2, icon: Icons.soup_kitchen),
            ],
          ),
        ),
        SizedBox(height: TavliSpacing.medium),
        GalleryLabeled(
          'Sličica u kartici na računaru · visina 120',
          TavliThumbnail.banner(tintIndex: 2),
        ),
        SizedBox(height: TavliSpacing.medium),
        GalleryLabeled(
          'Avatar 40 (36 na iOS-u) i oznaka skuvanog',
          Row(
            spacing: TavliSpacing.medium,
            children: [
              TavliAvatar(initials: 'AH', semanticLabel: 'Anja'),
              TavliAvatar(initials: 'M', size: 30),
              TavliTag.cooked(),
            ],
          ),
        ),
      ],
    );
  }
}

class _States extends StatefulWidget {
  const _States();

  @override
  State<_States> createState() => _StatesState();
}

class _StatesState extends State<_States> {
  // Okretanje je ugašeno dok se ne uključi, da galerija i testovi miruju.
  bool _spin = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TavliCard(
          child: TavliEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Još nema recepata',
            message:
                'Fotografiši recept ili upiši naziv jela, a AI će ga '
                'prepisati za tebe.',
            action: TavliButton.primary(
              label: 'Dodaj recept',
              icon: Icons.add,
              onPressed: () {},
            ),
          ),
        ),
        const SizedBox(height: TavliSpacing.medium),
        TavliCard(
          child: Column(
            children: [
              const SizedBox(height: TavliSpacing.medium),
              TickerMode(
                enabled: _spin,
                child: const TavliLoading(message: 'Pravim recept…'),
              ),
              const SizedBox(height: TavliSpacing.small),
              TavliSwitchRow(
                title: 'Animacija učitavanja',
                value: _spin,
                onChanged: (v) => setState(() => _spin = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
