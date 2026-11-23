import 'package:material_ui/material_ui.dart';

import '../icons/tavli_icons.dart';
import '../motion/motion.dart';
import '../tokens.dart';

/// Prazan ekran: ikonica u mekom krugu, naslov, objašnjenje i opciona
/// akcija (npr. `TavliButton.primary` „Dodaj recept“). Centriran, najviše
/// 360 širine.
class TavliEmptyState extends StatelessWidget {
  const TavliEmptyState({
    super.key,
    this.icon,
    this.glyph,
    this.art,
    required this.title,
    this.message,
    this.action,
  }) : assert(
         (icon != null ? 1 : 0) +
                 (glyph != null ? 1 : 0) +
                 (art != null ? 1 : 0) ==
             1,
         'tačno jedno: ikonica, Tavli ikonica ili crtež',
       );

  final IconData? icon;

  /// Ikonica iz Tavli seta ([TavliIcons]); zamenjuje [icon].
  final TavliIconData? glyph;

  /// Crtež umesto ikonice u krugu, npr. animirana prazna korpa
  /// aplikacije; sam nosi svoj opis za čitač ekrana.
  final Widget? art;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final message = this.message;
    final action = this.action;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TavliWidth.message),
        child: Padding(
          padding: const EdgeInsets.all(TavliSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (art case final art?)
                art
              else
                ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 72,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: switch (glyph) {
                        final g? => TavliIcon(
                          g,
                          size: 32,
                          color: c.onPrimaryContainer,
                        ),
                        null => Icon(
                          icon,
                          size: 32,
                          color: c.onPrimaryContainer,
                        ),
                      },
                    ),
                  ),
                ),
              const SizedBox(height: TavliSpacing.medium),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: t.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: c.onSurface,
                  ),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(
                    fontSize: 15,
                    height: 1.45,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: TavliSpacing.large),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Učitavanje: krug koji se okreće (na Apple platformama sistemski) i
/// opcioni tekst ispod. Kad se traži smanjeno kretanje, krug miruje.
class TavliLoading extends StatelessWidget {
  const TavliLoading({super.key, this.message});

  /// npr. „Pravim recept…“. Bez teksta čitač ekrana kaže „Učitavanje“.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final message = this.message;
    final still = reduceMotion(context);
    return Semantics(
      label: message ?? 'Učitavanje',
      liveRegion: true,
      excludeSemantics: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 32,
              child: still
                  ? CircularProgressIndicator(
                      value: 0.7,
                      strokeWidth: 3,
                      color: c.primary,
                    )
                  : CircularProgressIndicator.adaptive(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(c.primary),
                    ),
            ),
            if (message != null) ...[
              const SizedBox(height: TavliSpacing.medium),
              Text(
                message,
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: c.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Napredak posla koji traje (npr. pravljenje plana): traka visine 6,
/// zaobljena, u boji teme, i tekst ispod („Pripremljeno 3 od 7 obroka.“).
/// Bez [value] traka ide bez kraja; kad se traži smanjeno kretanje, miruje.
class TavliProgressBar extends StatelessWidget {
  const TavliProgressBar({
    super.key,
    this.value,
    this.message,
    required this.semanticLabel,
  });

  /// Od 0 do 1; `null` kada se ne zna koliko je ostalo.
  final double? value;
  final String? message;

  /// npr. „Napredak predloga“.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final message = this.message;
    final value = this.value ?? (reduceMotion(context) ? 0 : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.small,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            color: c.primary,
            backgroundColor: c.surfaceContainerHighest,
            semanticsLabel: semanticLabel,
          ),
        ),
        if (message != null)
          Text(message, style: t.bodyMedium?.copyWith(color: c.onSurface)),
      ],
    );
  }
}
