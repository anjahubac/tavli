import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/router.dart';
import 'profile_account_section.dart';
import 'profile_household_section.dart';
import 'settings_page.dart';
import 'tastes/taste_labels.dart';
import 'tastes/tastes_providers.dart';

/// Profil i podešavanja, kao na platnu: nalog, domaćinstvo, ishrana,
/// podešavanja i brisanje naloga; na širokom ekranu nalog, ishrana i
/// brisanje levo, domaćinstvo i podešavanja desno.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsSection(
      title: 'Podešavanja',
      children: [
        TavliListGroup(
          children: [
            TavliListRow(
              title: 'Izgled',
              subtitle: 'Boje, tema i svetli ili tamni režim',
              leading: const TavliIcon(TavliIcons.palette),
              showChevron: true,
              onTap: () => context.go('/profile/appearance'),
            ),
            TavliListRow(
              title: 'AI ključevi',
              subtitle: 'Gemini, Groq, OpenRouter',
              leading: const TavliIcon(TavliIcons.key),
              showChevron: true,
              onTap: () => context.go('/profile/ai-keys'),
            ),
          ],
        ),
      ],
    );
    const account = AccountSection();
    const household = HouseholdSection();
    const diet = _DietSection();
    const delete = DeleteAccountSection();
    return SettingsPage(
      title: 'Profil',
      // Otvoren direktnom adresom nema kuda nazad, pa vodi na početni tab.
      fallbackLocation: homeLocation,
      backWhenWide: false,
      children: [
        if (isWideSettings(context))
          SettingsColumns(
            start: const [account, diet, delete],
            end: [household, settings],
          )
        else
          SettingsColumns(
            start: [account, household, diet, settings, delete],
            end: const [],
          ),
      ],
    );
  }
}

/// Odeljak „Ishrana“: ulaz u Ukuse i alergene sa kratkim pregledom izbora.
class _DietSection extends ConsumerWidget {
  const _DietSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allergens = ref.watch(allergenSelectionProvider).value?.length ?? 0;
    final dish = ref.watch(dishPreferencesProvider).value;
    final cuisine = ref.watch(cuisinePreferencesProvider).value;
    final food = ref.watch(foodPreferencesProvider).value;
    final favorites = ref.watch(favoriteRecipeIdsProvider).value?.length ?? 0;
    final likes =
        (dish?.liked.length ?? 0) +
        (cuisine?.liked.length ?? 0) +
        (food?.liked.length ?? 0);
    return SettingsSection(
      title: 'Ishrana',
      children: [
        TavliListGroup(
          children: [
            TavliListRow(
              title: 'Ukusi i alergeni',
              subtitle: tastesSummary(
                allergens: allergens,
                likes: likes,
                favorites: favorites,
              ),
              leading: const TavliIcon(TavliIcons.like),
              showChevron: true,
              onTap: () => context.go('/profile/tastes'),
            ),
          ],
        ),
      ],
    );
  }
}
