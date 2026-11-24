import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../icons/tavli_icons.dart';
import '../theme/tavli_colors.dart';
import '../tokens.dart';
import 'tavli_list.dart';

/// Kolona u [TavliDataTable].
class TavliColumn {
  const TavliColumn(this.label, {this.flex = 1, this.alignEnd = false});

  final String label;

  /// Udeo širine u odnosu na ostale kolone.
  final int flex;

  /// Poravnanje desno (količine, brojevi).
  final bool alignEnd;
}

/// Red u [TavliDataTable]: po jedan tekst za svaku kolonu.
class TavliTableRow {
  const TavliTableRow(
    this.cells, {
    this.onTap,
    this.onSecondaryTap,
    this.onRemove,
    this.removeLabel = 'Ukloni',
  });

  final List<String> cells;
  final VoidCallback? onTap;

  /// Kanta na kraju reda, vidljiva dok je miš iznad reda ili je red u
  /// fokusu (platno, računar · Ostava). Čitač ekrana dobija istu akciju.
  final VoidCallback? onRemove;

  /// Oznaka kante za čitač ekrana i oblačić, npr. „Ukloni iz ostave“.
  final String removeLabel;

  /// Desni klik: dobija mesto klika, za `showTavliActionMenu`.
  final ValueChanged<Offset>? onSecondaryTap;
}

/// Tabela za računar (Ostava: Namirnica i Količina): zaglavlje sa
/// prigušenim nazivima kolona, redovi od najmanje 48 sa razdelnicima, u
/// okviru radijusa 16. Prazna ćelija se prikazuje prazna. Desni klik na red
/// otvara meni akcija (`showTavliActionMenu` sa mestom klika). Kad bar jedan
/// red ima [TavliTableRow.onRemove], tabela dobija uzanu kolonu za kantu.
class TavliDataTable extends StatelessWidget {
  const TavliDataTable({super.key, required this.columns, required this.rows})
    : assert(columns.length > 0);

  final List<TavliColumn> columns;
  final List<TavliTableRow> rows;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final x = TavliColors.of(context);

    final removable = rows.any((r) => r.onRemove != null);
    Widget line(
      List<String> cells, {
      required TextStyle? style,
      required double minHeight,
      Widget? action,
    }) => ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: TavliSpacing.medium,
          end: removable ? TavliSpacing.small : TavliSpacing.medium,
          top: TavliSpacing.small,
          bottom: TavliSpacing.small,
        ),
        child: Row(
          spacing: TavliSpacing.medium,
          children: [
            for (final (i, col) in columns.indexed)
              Expanded(
                flex: col.flex,
                child: Text(
                  i < cells.length ? cells[i] : '',
                  textAlign: col.alignEnd ? TextAlign.end : TextAlign.start,
                  style: style,
                ),
              ),
            if (removable) SizedBox(width: _actionSide, child: action),
          ],
        ),
      ),
    );

    final header = Semantics(
      header: true,
      child: ColoredBox(
        color: Color.lerp(c.surface, x.bg, 0.6)!,
        child: line(
          [for (final col in columns) col.label],
          minHeight: 40,
          style: t.labelMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.onSurfaceVariant,
          ),
        ),
      ),
    );
    final body = t.bodyLarge?.copyWith(
      fontSize: 15,
      height: 1.35,
      color: c.onSurface,
    );

    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TavliRadius.field),
        side: BorderSide(color: x.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          for (final row in rows) ...[
            TavliDivider(color: x.line),
            _TableRowView(
              row: row,
              builder: (action) =>
                  line(row.cells, minHeight: 48, style: body, action: action),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dodirna površina kante u tabeli.
const double _actionSide = 44;

/// Visina kante: red od 48 ostaje iste visine kao red bez nje.
const double _actionHeight = 32;

/// Jedan red tabele: kanta se pokazuje dok je miš iznad reda ili je fokus
/// u redu; dodir na red ostaje [TavliTableRow.onTap].
class _TableRowView extends StatefulWidget {
  const _TableRowView({required this.row, required this.builder});

  final TavliTableRow row;
  final Widget Function(Widget? action) builder;

  @override
  State<_TableRowView> createState() => _TableRowViewState();
}

class _TableRowViewState extends State<_TableRowView> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final onRemove = row.onRemove;
    final c = Theme.of(context).colorScheme;
    final showAction = onRemove != null && (_hovered || _focused);
    final action = showAction
        ? Tooltip(
            message: row.removeLabel,
            excludeFromSemantics: true,
            child: IconButton(
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              constraints: const BoxConstraints.tightFor(
                width: _actionSide,
                height: _actionHeight,
              ),
              icon: TavliIcon(TavliIcons.delete, size: 20, color: c.error),
            ),
          )
        : null;
    final content = MergeSemantics(
      child: Semantics(
        customSemanticsActions: onRemove == null
            ? null
            : {CustomSemanticsAction(label: row.removeLabel): onRemove},
        child: InkWell(
          onTap: row.onTap,
          onSecondaryTapUp: row.onSecondaryTap == null
              ? null
              : (d) => row.onSecondaryTap!(d.globalPosition),
          child: widget.builder(
            action == null ? null : ExcludeSemantics(child: action),
          ),
        ),
      ),
    );
    if (onRemove == null) return content;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (v) => setState(() => _focused = v),
        child: content,
      ),
    );
  }
}
