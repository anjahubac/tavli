import 'package:material_ui/material_ui.dart';

import '../theme/tavli_status_colors.dart';
import '../tokens.dart';

/// Značenje napomene; boje su iste u svakoj temi.
enum TavliNoticeTone { info, warning, success, error }

/// Napomena: radijus 16, bez ivice, ikonica i tekst u boji značenja.
/// Opcioni link („Nabavka“) stoji ispod teksta.
class TavliNotice extends StatelessWidget {
  const TavliNotice({
    super.key,
    required this.message,
    this.tone = TavliNoticeTone.info,
    this.title,
    this.linkLabel,
    this.onLink,
  }) : assert(
         (linkLabel == null) == (onLink == null),
         'link traži i tekst i radnju',
       );

  final String message;
  final TavliNoticeTone tone;

  /// Podebljan red iznad teksta.
  final String? title;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final status = TavliStatusColors.of(context);
    final (fg, bg, icon) = switch (tone) {
      TavliNoticeTone.info => (
        status.info.foreground,
        status.info.background,
        Icons.info_outline_rounded,
      ),
      TavliNoticeTone.warning => (
        status.warning.foreground,
        status.warning.background,
        Icons.warning_amber_rounded,
      ),
      TavliNoticeTone.success => (
        status.success.foreground,
        status.success.background,
        Icons.check_circle_outline_rounded,
      ),
      TavliNoticeTone.error => (
        c.onErrorContainer,
        c.errorContainer,
        Icons.error_outline_rounded,
      ),
    };
    final title = this.title;
    final linkLabel = this.linkLabel;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TavliRadius.field),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TavliSpacing.medium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 20, color: fg)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        title,
                        style: t.bodyMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: fg,
                        ),
                      ),
                    ),
                  Text(
                    message,
                    style: t.bodyMedium?.copyWith(
                      fontSize: 15,
                      height: 1.4,
                      color: fg,
                    ),
                  ),
                  if (linkLabel != null)
                    Semantics(
                      link: true,
                      child: InkWell(
                        onTap: onLink,
                        borderRadius: BorderRadius.circular(
                          TavliRadius.checkbox,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: 1,
                            child: Text(
                              linkLabel,
                              style: t.labelLarge?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: fg,
                                decoration: TextDecoration.underline,
                                decorationColor: fg,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Izgled naslova odeljka.
enum TavliSectionHeaderStyle {
  /// Mala velika slova sa razmakom: „NA UMU“, „SUTRA“, „ZA KOJE OBROKE“.
  caps,

  /// Običan podebljan: „Kupljeno · 2“.
  bold,

  /// Naslov dana u Planu: „Petak, 13. novembar“ (20, ekstra podebljan).
  title,
}

/// Naslov odeljka u listi ili na kartici, sa opcionom akcijom desno.
class TavliSectionHeader extends StatelessWidget {
  const TavliSectionHeader(
    this.title, {
    super.key,
    this.style = TavliSectionHeaderStyle.caps,
    this.trailing,
  });

  final String title;
  final TavliSectionHeaderStyle style;

  /// npr. `TavliButton.text` „Prikaži sve“.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final caps = style == TavliSectionHeaderStyle.caps;
    final text = Text(
      caps ? title.toUpperCase() : title,
      semanticsLabel: title,
      style: switch (style) {
        TavliSectionHeaderStyle.caps => t.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          height: 1.3,
          color: c.onSurfaceVariant,
        ),
        TavliSectionHeaderStyle.bold => t.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: c.onSurface,
        ),
        TavliSectionHeaderStyle.title => t.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          height: 1.3,
          color: c.onSurface,
        ),
      },
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TavliSpacing.small),
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: text)),
          ?trailing,
        ],
      ),
    );
  }
}
