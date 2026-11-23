import 'package:material_ui/material_ui.dart';

import '../controls/tavli_button.dart';
import '../tokens.dart';
import 'tavli_card.dart';
import 'tavli_list.dart';
import 'tavli_notice.dart';

/// Sledeći neskuvan obrok na Početnoj: kartica u boji teme (radijus 20,
/// razmak 18) sa „SLEDEĆE · VEČERA“, nazivom jela (20/800 na telefonu,
/// 24/800 na računaru), detaljima i dugmadima „Kuvaj“ i „Skuvano“ ispod.
///
/// Dugmad su u redu kada staju, inače jedno ispod drugog; uvek iste visine.
class TavliNextMealCard extends StatelessWidget {
  const TavliNextMealCard({
    super.key,
    required this.overline,
    required this.title,
    this.detail,
    this.actions = const [],
    this.wide = false,
  });

  /// Širok raspored (računar, tablet): veći naziv jela.
  final bool wide;

  /// „Sledeće · Večera“; prikazuje se velikim slovima.
  final String overline;

  /// Naziv jela: „Musaka od krompira“.
  final String title;

  /// „75 min · 4 porcije“.
  final String? detail;

  /// npr. `TavliButton.primary` „Kuvaj“ i `TavliButton.secondary` „Skuvano“.
  final List<TavliButton> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final titleSize = wide ? 24.0 : 20.0;
    final detail = this.detail;
    return TavliCard(
      variant: TavliCardVariant.highlighted,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overline.toUpperCase(),
            semanticsLabel: overline,
            style: t.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.72,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(
              title,
              style: t.titleLarge?.copyWith(
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.02 * titleSize,
                height: 1.25,
              ),
            ),
          ),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(detail, style: t.bodyMedium?.copyWith(fontSize: 14)),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: TavliSpacing.medium),
            // U redu kada staju (iste visine), inače jedno ispod drugog.
            OverflowBar(spacing: 10, overflowSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Jedan obrok u [TavliUpcomingMeals]: vrsta obroka i naziv jela.
class TavliUpcomingMeal {
  const TavliUpcomingMeal({required this.label, required this.title});

  /// „Ručak“.
  final String label;

  /// „Punjene paprike“.
  final String title;
}

/// Obroci koji dolaze (Početna: „Sutra“).
///
/// Telefon: naslov odeljka i nazivi jela u jednom redu („Kajgana ·
/// Punjene paprike“). [card] (računar, desno od današnjih obroka):
/// kartica sa naslovom i obrokom po redu (vrsta obroka iznad naziva), sa
/// razdelnicima.
class TavliUpcomingMeals extends StatelessWidget {
  const TavliUpcomingMeals({
    super.key,
    required this.title,
    required this.meals,
    this.card = false,
  });

  /// „Sutra“.
  final String title;
  final List<TavliUpcomingMeal> meals;
  final bool card;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (!card) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TavliSectionHeader(title),
          Text(
            meals.map((m) => m.title).join(' · '),
            style: t.bodyLarge?.copyWith(fontSize: 15, height: 1.4),
          ),
        ],
      );
    }
    return TavliCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: TavliSectionHeader(title),
          ),
          for (final (i, meal) in meals.indexed) ...[
            if (i > 0) const TavliDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.label,
                    style: t.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                  Text(
                    meal.title,
                    style: t.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kratka poruka o stanju ispod liste, npr. „Svi današnji obroci su
/// skuvani.“ (15/600).
class TavliStatusText extends StatelessWidget {
  const TavliStatusText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: TavliSpacing.small),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );
}
