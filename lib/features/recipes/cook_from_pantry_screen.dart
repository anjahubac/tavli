import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/pantry_suggestions.dart';
import '../../domain/recipe_format.dart';
import '../pantry/pantry_providers.dart';
import 'recipe_photo.dart';
import 'recipe_providers.dart';

/// Putanja ekrana „Šta da skuvam?“ (TRELLO-103).
const cookFromPantryPath = '/recipes/from-pantry';

/// Najviše naziva koji fale u drugom redu; ostali su „+N“.
const _missingShown = 2;

/// Predlozi iz ostave: `null` kad je ostava prazna (ili je sve potrošeno).
final pantrySuggestionsProvider =
    FutureProvider.autoDispose<List<PantrySuggestion>?>((ref) async {
      final stock = await ref.watch(pantryStockProvider.future);
      final recipes = await ref.watch(recipesProvider.future);
      final pantry = [
        for (final s in stock)
          if (s.quantity == null || s.quantity! > 0)
            (name: s.name, foodId: s.foodId, quantity: s.quantity),
      ];
      if (pantry.isEmpty) return null;
      return suggestFromPantry(recipes, pantry);
    });

/// „Šta da skuvam?“: sačuvani recepti poređani po tome koliko sastojaka
/// već imaš u ostavi, sa oznakom „Imaš sve“ ili „Fali N“ u drugom redu.
/// Radi bez mreže; dodir otvara recept. Platno nema ovaj ekran, pa je
/// sklopljen od postojećih delova: red liste sa sličicom i drugim redom
/// (oznaka nije desno, da red ne preliva na uskom ekranu sa većim tekstom).
class CookFromPantryScreen extends ConsumerWidget {
  const CookFromPantryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = switch (ref.watch(pantrySuggestionsProvider)) {
      AsyncData(value: null) => TavliEmptyState(
        glyph: TavliIcons.pantry,
        title: 'Ostava je prazna',
        message: 'Dodaj šta imaš kod kuće, pa ćemo naći recept.',
        action: TavliButton.primary(
          label: 'Otvori ostavu',
          onPressed: () => context.go('/pantry'),
        ),
      ),
      AsyncData(value: final list?) when list.isEmpty => const TavliEmptyState(
        glyph: TavliIcons.recipes,
        title: 'Nema recepta od onoga što imaš',
        message: 'Nijedan sačuvan recept ne koristi namirnice iz ostave.',
      ),
      AsyncData(value: final list?) => _Suggestions(list),
      AsyncError() => const TavliEmptyState(
        glyph: TavliIcons.recipes,
        title: 'Predlozi trenutno nisu dostupni',
        message: 'Pokušaj ponovo malo kasnije.',
      ),
      _ => const TavliLoading(),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Šta da skuvam?')),
      body: body,
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions(this.suggestions);

  final List<PantrySuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TavliWidth.panel),
        child: ListView.builder(
          padding: const EdgeInsets.all(TavliSpacing.large),
          itemCount: suggestions.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: TavliSpacing.medium),
                child: Text(
                  'Iz onoga što imaš u ostavi. So, biber, ulje i voda se ne '
                  'računaju.',
                  style: t.bodyMedium,
                ),
              );
            }
            final s = suggestions[i - 1];
            final path = s.recipe.imagePath;
            return TavliListRow(
              title: s.recipe.title,
              subtitle: missingLine(s),
              leading: TavliThumbnail.row(
                tintIndex: i - 1,
                photo: path == null ? null : RecipePhoto(path),
              ),
              showChevron: true,
              onTap: () => context.push('/recipes/${s.recipe.id}'),
            );
          },
        ),
      ),
    );
  }
}

/// Drugi red: koliko i šta fali („Fali 4: sir, kore, +2“), a kad ne fali
/// ništa, „Imaš sve“ sa vremenom i porcijama kao na listi recepata.
String missingLine(PantrySuggestion s) {
  if (s.hasEverything) {
    return [
      'Imaš sve',
      if (s.recipe.prepMinutes case final m?) '$m min',
      servingsLabel(s.recipe.servings),
    ].join(' · ');
  }
  final shown = s.missing.take(_missingShown).join(', ');
  final rest = s.missing.length - _missingShown;
  final names = rest > 0 ? '$shown, +$rest' : shown;
  return 'Fali ${s.missing.length}: $names';
}
