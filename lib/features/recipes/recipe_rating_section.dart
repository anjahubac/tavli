import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/recipe_rating.dart';
import '../../providers.dart';
import '../settings/tastes/tastes_providers.dart';
import 'recipe_providers.dart';

/// Boja popunjene zvezdice (prosek i ocena).
const ratingStarColor = Color(0xFFA86A12);

/// Najveća širina panela i dugmadi na širokom ekranu.
const _panelMaxWidth = 480.0;

/// „Omiljeni“ i „Oceni“ ispod naslova, sa panelom za ocenu koji se otvara u
/// stranici. Ocena se menja, ne briše; beleška je privatna.
class RecipeRatingSection extends ConsumerStatefulWidget {
  const RecipeRatingSection({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeRatingSection> createState() =>
      _RecipeRatingSectionState();
}

class _RecipeRatingSectionState extends ConsumerState<RecipeRatingSection> {
  bool _open = false;

  Future<void> _toggleFavorite(bool isFavorite) => ref
      .read(favoriteRepositoryProvider)
      .setFavorite(widget.recipeId, isFavorite: !isFavorite);

  @override
  Widget build(BuildContext context) {
    final favorite =
        ref.watch(favoriteRecipeIdsProvider).value?.contains(widget.recipeId) ??
        false;
    final mine = ref.watch(recipeMyRatingProvider(widget.recipeId)).value;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: TavliSpacing.small,
          runSpacing: TavliSpacing.small,
          children: [
            _Pill(
              label: 'Omiljeni',
              icon: TavliIcons.like,
              filled: favorite,
              iconColor: favorite ? theme.colorScheme.error : null,
              selected: favorite,
              toggled: favorite,
              onPressed: () => _toggleFavorite(favorite),
            ),
            _Pill(
              label: mine == null ? 'Oceni' : 'Tvoja ocena: ${mine.stars}',
              icon: TavliIcons.star,
              filled: mine != null,
              iconColor: mine == null ? null : ratingStarColor,
              selected: _open,
              trailing: _open ? TavliIcons.chevronUp : TavliIcons.chevronDown,
              onPressed: () => setState(() => _open = !_open),
            ),
          ],
        ),
        if (_open) ...[
          const SizedBox(height: TavliSpacing.medium),
          _RatingPanel(
            recipeId: widget.recipeId,
            current: mine,
            onDone: () => setState(() => _open = false),
          ),
        ] else if (mine?.personalNote != null) ...[
          const SizedBox(height: TavliSpacing.medium),
          _NoteBox(mine!.personalNote!),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.iconColor,
    this.filled = false,
    this.trailing,
    this.toggled,
  });

  final String label;
  final TavliIconData icon;
  final Color? iconColor;
  final bool filled;
  final TavliIconData? trailing;
  final bool selected;

  /// Zadato samo za prekidač („Omiljeni“); čitači ekrana čitaju stanje.
  final bool? toggled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    return Semantics(
      button: true,
      toggled: toggled,
      expanded: trailing == null ? null : selected,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? scheme.primary : x.boxLine,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  TavliIcon(icon, size: 20, color: iconColor, filled: filled),
                  Flexible(child: Text(label)),
                  if (trailing != null) TavliIcon(trailing!, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingPanel extends ConsumerStatefulWidget {
  const _RatingPanel({
    required this.recipeId,
    required this.current,
    required this.onDone,
  });

  final String recipeId;
  final RecipeRating? current;
  final VoidCallback onDone;

  @override
  ConsumerState<_RatingPanel> createState() => _RatingPanelState();
}

class _RatingPanelState extends ConsumerState<_RatingPanel> {
  late int _stars = widget.current?.stars ?? 0;
  late final _note = TextEditingController(
    text: widget.current?.personalNote ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_stars == 0 || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Prazna beleška briše postojeću.
      await ref
          .read(recipeRatingRepositoryProvider)
          .save(
            recipeId: widget.recipeId,
            stars: _stars,
            personalNote: _note.text,
          );
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showTavliMessageOn(messenger, 'Ocena nije sačuvana. Pokušaj ponovo.');
      return;
    }
    if (!mounted) return;
    widget.onDone();
    showTavliMessageOn(messenger, 'Ocena je sačuvana.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final x = TavliColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _panelMaxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: x.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(TavliSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Da li ti se svidelo?',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: TavliSpacing.small),
                Semantics(
                  container: true,
                  label: 'Ocena',
                  child: Wrap(
                    children: [
                      for (var n = 1; n <= 5; n++)
                        Semantics(
                          button: true,
                          inMutuallyExclusiveGroup: true,
                          selected: n == _stars,
                          label: '$n od 5',
                          excludeSemantics: true,
                          onTap: () => setState(() => _stars = n),
                          child: InkResponse(
                            radius: 26,
                            onTap: () => setState(() => _stars = n),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: TavliIcon(
                                  TavliIcons.star,
                                  size: 32,
                                  filled: n <= _stars,
                                  color: n <= _stars ? ratingStarColor : muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: TavliSpacing.small),
                TavliTextField(
                  label: 'Privatna beleška (nije obavezno)',
                  hint: 'Npr. sledeći put manje soli',
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: TavliSpacing.small),
                Row(
                  spacing: 6,
                  children: [
                    TavliIcon(TavliIcons.lock, size: 13, color: muted),
                    Expanded(
                      child: Text(
                        'Vidiš samo ti. Ukućani vide samo prosek.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TavliSpacing.large),
                TavliButtonRow(
                  expand: true,
                  children: [
                    TavliButton.secondary(
                      label: 'Otkaži',
                      onPressed: widget.onDone,
                    ),
                    TavliButton.primary(
                      label: 'Sačuvaj',
                      // Bez izabrane zvezdice nema šta da se sačuva.
                      onPressed: _stars == 0 || _saving ? null : _save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Privatna beleška autora, prikazana ispod dugmadi kad je panel zatvoren.
class _NoteBox extends StatelessWidget {
  const _NoteBox(this.note);

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _panelMaxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TavliColors.of(context).bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(TavliSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    TavliIcon(TavliIcons.lock, size: 13, color: muted),
                    Text(
                      'TVOJA BELEŠKA',
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(note),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
