import 'package:material_ui/material_ui.dart';

import '../icons/tavli_icons.dart';
import '../motion/motion.dart';
import '../tokens.dart';

/// Proširivi blok: red sa naslovom, opcionim podnaslovom i strelicom
/// nadole; dodir otvara sadržaj ispod. Red je visok najmanje 52, sa
/// razmakom 14 sa strane ([inset]) kao red liste; bez [inset] je poravnat
/// sa ivicom (npr. „Više opcija“ u formi).
///
/// [trailing] stoji levo od strelice (npr. `TavliIconButton` „Zameni
/// jelo“) i ne otvara blok. Sadržaj je poravnat sa tekstom reda.
class TavliExpandable extends StatefulWidget {
  const TavliExpandable({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.initiallyExpanded = false,
    this.inset = true,
    required this.children,
  });

  final String title;

  /// Može imati više redova (npr. naziv jela i poreklo).
  final String? subtitle;
  final Widget? trailing;
  final bool initiallyExpanded;
  final bool inset;
  final List<Widget> children;

  @override
  State<TavliExpandable> createState() => _TavliExpandableState();
}

class _TavliExpandableState extends State<TavliExpandable> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final side = widget.inset ? TavliSpacing.medium : 0.0;
    final subtitle = widget.subtitle;
    final duration = TavliMotion.duration(context, TavliMotion.feedback);
    final header = Semantics(
      button: true,
      expanded: _open,
      child: InkWell(
        borderRadius: BorderRadius.circular(TavliRadius.compact),
        onTap: () => setState(() => _open = !_open),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: side,
              vertical: TavliSpacing.small / 2,
            ),
            child: Row(
              spacing: TavliSpacing.small,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.title, style: t.labelLarge),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: t.bodyMedium?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                ?widget.trailing,
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: duration,
                  child: TavliIcon(
                    TavliIcons.chevronDown,
                    size: 20,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final body = _open
        ? Padding(
            padding: EdgeInsets.fromLTRB(side, 0, side, TavliSpacing.small),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          )
        : const SizedBox(width: double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        // Sa smanjenim kretanjem (trajanje 0) sadržaj se pojavi odmah.
        if (duration == Duration.zero)
          body
        else
          AnimatedSize(
            duration: duration,
            alignment: Alignment.topCenter,
            child: body,
          ),
      ],
    );
  }
}
