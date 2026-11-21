import 'dart:math' as math;

import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:material_ui/material_ui.dart';

import '../controls/tavli_icon_button.dart';
import '../icons/tavli_icons.dart';
import '../theme/tavli_colors.dart';
import '../theme/tavli_status_colors.dart';
import '../tokens.dart';
import 'tavli_list.dart';
import 'tavli_tag.dart';

/// Izbor perioda: strelica levo, naziv perioda i strelica desno
/// („9. – 15. novembar“, „Novembar 2026“).
///
/// Na telefonu zauzima ceo red i naziv je u sredini; [compact] ga skuplja na
/// širinu sadržaja, za zaglavlje na računaru. `null` radnja isključuje
/// strelicu (početak ili kraj plana).
class TavliPeriodSwitcher extends StatelessWidget {
  const TavliPeriodSwitcher({
    super.key,
    required this.label,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
    this.compact = false,
  });

  final String label;

  /// Opis strelice levo, npr. „Prethodna nedelja“.
  final String previousLabel;

  /// Opis strelice desno, npr. „Sledeća nedelja“.
  final String nextLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final size = compact ? 15.0 : 16.0;
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: t.titleMedium?.copyWith(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: c.onSurface,
      ),
    );
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        TavliIconButton(
          glyph: TavliIcons.back,
          semanticLabel: previousLabel,
          onPressed: onPrevious,
        ),
        if (compact) Flexible(child: text) else Expanded(child: text),
        TavliIconButton(
          glyph: TavliIcons.chevronRight,
          semanticLabel: nextLabel,
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// Jedan dan u [TavliWeekStrip].
class TavliStripDay {
  const TavliStripDay({
    required this.weekday,
    required this.day,
    required this.semanticLabel,
    this.enabled = true,
  });

  /// Skraćen dan: „Pon“.
  final String weekday;

  /// Dan u mesecu: „9“.
  final String day;

  /// Šta čitač ekrana kaže: „Ponedeljak, 9. novembar, 3 obroka“.
  final String semanticLabel;

  /// Dan van plana: prikazan bledo i ne bira se.
  final bool enabled;
}

/// Nedelja na telefonu: sedam dana u redu (visina 60, radijus 16), izabran
/// dan u boji teme.
class TavliWeekStrip extends StatelessWidget {
  const TavliWeekStrip({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<TavliStripDay> days;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final x = TavliColors.of(context);
    // Dani su iste visine (najviši određuje red).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 2,
        children: [
          for (final (i, d) in days.indexed)
            Expanded(
              child: Builder(
                builder: (context) {
                  final selected = i == selectedIndex;
                  final color = selected
                      ? c.onPrimary
                      : d.enabled
                      ? c.onSurface
                      : x.boxLine;
                  return Semantics(
                    button: d.enabled,
                    selected: selected,
                    enabled: d.enabled,
                    label: d.semanticLabel,
                    onTap: d.enabled ? () => onSelected(i) : null,
                    excludeSemantics: true,
                    child: Material(
                      color: selected ? c.primary : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(TavliRadius.field),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: d.enabled ? () => onSelected(i) : null,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 60),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            // Uzak telefon i krupan tekst: tekst se smanjuje
                            // da stane u svoj deo reda.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 2,
                                children: [
                                  Text(
                                    d.weekday,
                                    style: t.labelMedium?.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    d.day,
                                    style: t.titleMedium?.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Jelo u danu kalendara: naziv i da li je skuvano.
class TavliCalendarMark {
  const TavliCalendarMark(this.title, {this.done = false});

  final String title;
  final bool done;
}

/// Jedan dan u [TavliMonthCalendar].
class TavliCalendarDay {
  const TavliCalendarDay({
    required this.day,
    required this.semanticLabel,
    this.marks = const [],
    this.active = true,
  });

  /// Dan u mesecu: „13“.
  final String day;

  /// Šta čitač ekrana kaže: „Petak, 13. novembar, 3 obroka, danas“.
  final String semanticLabel;

  /// Jela tog dana, redom obroka.
  final List<TavliCalendarMark> marks;

  /// Dan van meseca ili plana: samo broj, bledo, ne bira se.
  final bool active;
}

/// Mesec u mreži 7 x n (ponedeljak prvi).
///
/// Telefon: ćelije visine 40 (radijus 14) sa brojem i tačkom za svako jelo
/// (puna = skuvano, prsten = u planu); izabran dan u boji teme. Ispod ide
/// [TavliCalendarLegend].
///
/// Računar ([detailed]): mreža popunjava visinu, ćelija (radijus 12, ivica
/// 1 px) ima broj i nazive jela, sa kvačicom ispred skuvanih; izabran dan
/// ima ivicu 2 px i broj u krugu boje teme. Kad visine nema dovoljno (nizak
/// prozor, krupan tekst), mreža se pomera.
class TavliMonthCalendar extends StatelessWidget {
  const TavliMonthCalendar({
    super.key,
    required this.weekdays,
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
    this.detailed = false,
  }) : assert(weekdays.length == 7 && days.length % 7 == 0);

  /// Nazivi dana u zaglavlju, od ponedeljka: „P“ … „N“ ili „Pon“ … „Ned“.
  final List<String> weekdays;
  final List<TavliCalendarDay> days;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final bool detailed;

  @override
  Widget build(BuildContext context) =>
      detailed ? _detailedGrid(context) : _compactGrid(context);

  Widget _header(BuildContext context, {required bool caps}) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: Row(
        spacing: caps ? 6 : 2,
        children: [
          for (final w in weekdays)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: caps ? 10 : 0),
                child: Text(
                  caps ? w.toUpperCase() : w,
                  textAlign: caps ? TextAlign.start : TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: t.labelMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: caps ? 0.72 : null,
                    height: 1.3,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _compactGrid(BuildContext context) {
    final rows = days.length ~/ 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: [
        _header(context, caps: false),
        for (var r = 0; r < rows; r++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 2,
              children: [
                for (var i = r * 7; i < r * 7 + 7; i++)
                  Expanded(
                    child: _CompactCell(
                      day: days[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _detailedGrid(BuildContext context) {
    final rows = days.length ~/ 7;
    const gap = 6.0;
    final minRow = MediaQuery.textScalerOf(context).scale(72);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        _header(context, caps: true),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fill =
                  constraints.maxHeight.isFinite &&
                  (constraints.maxHeight - gap * (rows - 1)) / rows >= minRow;
              Widget row(int r) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: gap,
                children: [
                  for (var i = r * 7; i < r * 7 + 7; i++)
                    Expanded(
                      child: _DetailedCell(
                        day: days[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              );
              if (fill) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: gap,
                  children: [
                    for (var r = 0; r < rows; r++) Expanded(child: row(r)),
                  ],
                );
              }
              return ListView.separated(
                itemCount: rows,
                separatorBuilder: (_, _) => const SizedBox(height: gap),
                itemBuilder: (context, r) =>
                    SizedBox(height: minRow, child: row(r)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.filled, required this.ring});

  final bool done;
  final Color filled;
  final Color ring;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 6,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? filled : null,
        border: done ? null : Border.all(color: ring, width: 1.5),
      ),
    ),
  );
}

class _CompactCell extends StatelessWidget {
  const _CompactCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final TavliCalendarDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final x = TavliColors.of(context);
    if (!day.active) {
      return ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              day.day,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: t.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.3,
                color: x.boxLine,
              ),
            ),
          ),
        ),
      );
    }
    final fg = selected ? c.onPrimary : c.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: day.semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TavliRadius.compact),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Text(
                    day.day,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: t.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      height: 1.2,
                      color: fg,
                    ),
                  ),
                  // Tačke se prelamaju kad ih je više nego što staje.
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 3,
                    runSpacing: 3,
                    children: [
                      for (final m in day.marks)
                        _Dot(
                          done: m.done,
                          filled: selected ? c.onPrimary : c.primary,
                          ring: selected ? c.onPrimary : x.boxLine,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sadržaj koji se, kao `overflow: hidden` na platnu, odseca kad ne staje,
/// umesto da prijavi prelivanje.
class _Clipped extends StatelessWidget {
  const _Clipped({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: OverflowBox(
      fit: OverflowBoxFit.deferToChild,
      alignment: AlignmentDirectional.topStart,
      maxHeight: double.infinity,
      child: child,
    ),
  );
}

class _DetailedCell extends StatelessWidget {
  const _DetailedCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final TavliCalendarDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final x = TavliColors.of(context);
    final success = TavliStatusColors.of(context).success.foreground;
    final radius = BorderRadius.circular(12);
    if (!day.active) {
      return ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: _Clipped(
            child: Text(
              day.day,
              style: t.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.3,
                color: x.boxLine,
              ),
            ),
          ),
        ),
      );
    }
    final number = Text(
      day.day,
      style: t.labelLarge?.copyWith(
        fontSize: selected ? 12 : 13,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
        height: 1.2,
        color: selected ? c.onPrimary : c.onSurface,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: day.semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected
              ? BorderSide(color: c.primary, width: 2)
              : BorderSide(color: x.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _Clipped(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 20,
                        minWidth: 20,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected ? c.primary : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(widthFactor: 1, child: number),
                      ),
                    ),
                  ),
                  for (final m in day.marks)
                    Row(
                      spacing: 4,
                      children: [
                        if (m.done)
                          TavliIcon(TavliIcons.check, size: 12, color: success)
                        else
                          const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            m.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: t.bodySmall?.copyWith(
                              fontSize: 12,
                              height: 1.35,
                              color: m.done ? c.onSurfaceVariant : c.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Objašnjenje tačaka ispod mesečnog kalendara na telefonu: „skuvano“ i
/// „u planu“.
class TavliCalendarLegend extends StatelessWidget {
  const TavliCalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final x = TavliColors.of(context);
    final style = t.bodySmall?.copyWith(
      fontSize: 12,
      height: 1.3,
      color: c.onSurfaceVariant,
    );
    Widget item(bool done, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        _Dot(done: done, filled: c.primary, ring: x.boxLine),
        Text(label, style: style),
      ],
    );
    return ExcludeSemantics(
      child: Wrap(
        spacing: TavliSpacing.medium,
        runSpacing: 4,
        children: [item(true, 'skuvano'), item(false, 'u planu')],
      ),
    );
  }
}

/// Kartica obroka (Plan, Početna): vrsta obroka, naziv jela i detalji.
///
/// Telefon: radijus 20, razmak 14 x 16, strelica desno kad dodir otvara
/// obrok. Skuvan obrok je zasenčen, bez ivice, prigušenog teksta, sa
/// „· skuvano“ uz vrstu obroka i kvačicom desno.
///
/// [compact] je kartica nedeljne mreže na računaru: radijus 14, razmak 10,
/// vrsta obroka i zelena oznaka skuvanog gore, naziv ispod. Kad joj mreža
/// zada visinu, sadržaj koji ne staje se odseca.
class TavliMealCard extends StatelessWidget {
  const TavliMealCard({
    super.key,
    required this.label,
    required this.title,
    this.detail,
    this.cooked = false,
    this.muted = false,
    this.onTap,
    this.compact = false,
  });

  /// Vrsta obroka: „Večera“.
  final String label;

  /// Naziv jela: „Musaka od krompira“.
  final String title;

  /// Vreme, porcije i stanje: „75 min · 4 porcije“ (samo na telefonu).
  final String? detail;
  final bool cooked;

  /// Mesto bez jela („Nije planirano“): prigušen naziv, bez strelice.
  final bool muted;

  /// Otvara obrok; `null` kad nema šta da se otvori.
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final x = TavliColors.of(context);
    final shaded = cooked;
    final fg = shaded || muted ? c.onSurfaceVariant : c.onSurface;
    final labelText = Text(
      cooked && !compact ? '$label · skuvano' : label,
      style: t.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: c.onSurfaceVariant,
      ),
    );
    final titleText = Text(
      title,
      style: t.titleMedium?.copyWith(
        fontSize: compact ? 14 : 16,
        fontWeight: compact || shaded || muted
            ? FontWeight.w600
            : FontWeight.w700,
        height: 1.3,
        color: fg,
      ),
    );

    final Widget content;
    if (compact) {
      content = Padding(
        padding: const EdgeInsets.all(10),
        child: _Clipped(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Row(
                spacing: 6,
                children: [
                  Expanded(child: labelText),
                  if (cooked) const TavliTag.cooked(),
                ],
              ),
              titleText,
            ],
          ),
        ),
      );
    } else {
      final detail = this.detail;
      final trailing = cooked
          ? TavliIcon(TavliIcons.check, size: 20, color: c.onSurfaceVariant)
          : onTap == null
          ? null
          : TavliIcon(
              TavliIcons.chevronRight,
              size: 18,
              color: c.onSurfaceVariant,
            );
      content = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: TavliSpacing.medium,
        ),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  labelText,
                  titleText,
                  if (detail != null && detail.isNotEmpty)
                    Text(
                      detail,
                      style: t.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.4,
                        color: c.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      );
    }
    final background = shaded ? c.surfaceContainerHigh : c.surface;
    return Semantics(
      button: onTap != null,
      label: [
        label,
        title,
        if (!compact && detail != null && detail!.isNotEmpty) detail!,
        if (cooked) 'skuvano',
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            compact ? TavliRadius.compact : TavliRadius.card,
          ),
          side: BorderSide(color: shaded ? background : x.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Obroci izabranog dana ispod mesečnog kalendara na telefonu: jedna
/// kartica (radijus 20) sa redovima od najmanje 40 i razdelnicima.
class TavliMealList extends StatelessWidget {
  const TavliMealList({super.key, required this.children});

  final List<TavliMealRow> children;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TavliRadius.card),
        side: BorderSide(color: x.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in children.indexed) ...[
            if (i > 0) TavliDivider(color: x.line),
            row,
          ],
        ],
      ),
    );
  }
}

/// Red u [TavliMealList]: vrsta obroka, naziv i oznaka skuvanog ili
/// strelica.
class TavliMealRow extends StatelessWidget {
  const TavliMealRow({
    super.key,
    required this.label,
    required this.title,
    this.cooked = false,
    this.muted = false,
    this.onTap,
  });

  final String label;
  final String title;
  final bool cooked;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final scale = MediaQuery.textScalerOf(context);
    final trailing = cooked
        ? const TavliTag.cooked()
        : onTap == null
        ? null
        : TavliIcon(
            TavliIcons.chevronRight,
            size: 18,
            color: c.onSurfaceVariant,
          );
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          spacing: 12,
          children: [
            SizedBox(
              // Kolona vrsta obroka raste sa tekstom, da „Doručak“ stane.
              width: math.min(scale.scale(62), 160),
              child: Text(
                label,
                style: t.labelMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: c.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: t.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: cooked || muted ? c.onSurfaceVariant : c.onSurface,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: [label, title, if (cooked) 'skuvano'].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: onTap == null ? row : InkWell(onTap: onTap, child: row),
    );
  }
}

/// Zaglavlje dana u [TavliWeekGrid]: „Pon 9“.
class TavliWeekDay {
  const TavliWeekDay({
    required this.weekday,
    required this.day,
    required this.semanticLabel,
    this.highlighted = false,
  });

  final String weekday;
  final String day;
  final String semanticLabel;

  /// Izabran dan (danas): zaglavlje u boji teme.
  final bool highlighted;
}

/// Nedelja na računaru: sedam kolona dana, a u svakom redu po jedan obrok
/// ([TavliMealCard] sa `compact`). Kartice u redu su iste visine.
///
/// Kad ima mesta, mreža popunjava visinu kao na platnu; kad nema (nizak
/// prozor, krupan tekst), redovi su visoki koliko sadržaj i mreža se pomera.
class TavliWeekGrid extends StatelessWidget {
  const TavliWeekGrid({super.key, required this.days, required this.rows})
    : assert(days.length == 7);

  final List<TavliWeekDay> days;

  /// Redovi po obroku; svaki ima sedam mesta, `null` je prazno mesto.
  final List<List<Widget?>> rows;

  static const double _gap = TavliSpacing.small;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final header = Row(
      spacing: _gap,
      children: [
        for (final d in days)
          Expanded(
            child: Semantics(
              header: true,
              label: d.semanticLabel,
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: d.highlighted ? c.primary : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${d.weekday} '),
                            TextSpan(
                              text: d.day,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        style: t.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.3,
                          color: d.highlighted ? c.onPrimary : c.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final minRow = MediaQuery.textScalerOf(context).scale(76);
    List<Widget> cells(List<Widget?> row) => [
      for (var i = 0; i < 7; i++)
        Expanded(
          child: i < row.length ? row[i] ?? const SizedBox() : const SizedBox(),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = math.max(rows.length, 1);
        final available = constraints.maxHeight;
        final fill =
            available.isFinite &&
            (available - minRow / 2 - _gap * count) / count >= minRow;
        if (fill) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _gap,
            children: [
              header,
              for (final r in rows)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: _gap,
                    children: cells(r),
                  ),
                ),
            ],
          );
        }
        return ListView(
          children: [
            header,
            for (final r in rows) ...[
              const SizedBox(height: _gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: _gap,
                  children: cells(r),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
