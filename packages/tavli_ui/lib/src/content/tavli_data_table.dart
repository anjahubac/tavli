import 'package:material_ui/material_ui.dart';

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
  const TavliTableRow(this.cells, {this.onTap, this.onSecondaryTap});

  final List<String> cells;
  final VoidCallback? onTap;

  /// Desni klik: dobija mesto klika, za `showTavliActionMenu`.
  final ValueChanged<Offset>? onSecondaryTap;
}

/// Tabela za računar (Ostava: Namirnica i Količina): zaglavlje sa
/// prigušenim nazivima kolona, redovi od najmanje 48 sa razdelnicima, u
/// okviru radijusa 16. Prazna ćelija se prikazuje prazna. Desni klik na red
/// otvara meni akcija (`showTavliActionMenu` sa mestom klika).
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

    Widget line(
      List<String> cells, {
      required TextStyle? style,
      required double minHeight,
    }) => ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TavliSpacing.medium,
          vertical: TavliSpacing.small,
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
            MergeSemantics(
              child: InkWell(
                onTap: row.onTap,
                onSecondaryTapUp: row.onSecondaryTap == null
                    ? null
                    : (d) => row.onSecondaryTap!(d.globalPosition),
                child: line(row.cells, minHeight: 48, style: body),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
