import 'package:material_ui/material_ui.dart';

import '../motion/motion.dart';
import '../tokens.dart';

/// Prazan ekran: ikonica u mekom krugu, naslov, objašnjenje i opciona
/// akcija (npr. `TavliButton.primary` „Dodaj recept“). Centriran, najviše
/// 360 širine.
class TavliEmptyState extends StatelessWidget {
  const TavliEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
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
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(TavliSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 72,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 32, color: c.onPrimaryContainer),
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
