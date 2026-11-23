import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/router.dart';
import 'profile_account_section.dart';
import 'settings_page.dart';

/// Profil i podešavanja, kao na platnu: nalog, podešavanja i brisanje
/// naloga; na širokom ekranu nalog levo, ostalo desno.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'Profil',
      // Otvoren direktnom adresom nema kuda nazad, pa vodi na početni tab.
      fallbackLocation: homeLocation,
      backWhenWide: false,
      children: [
        SettingsColumns(
          start: const [AccountSection()],
          end: [
            SettingsSection(
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
                    if (kDebugMode)
                      TavliListRow(
                        title: 'Animacije',
                        subtitle: 'Pregled animacija (samo za razvoj)',
                        leading: const TavliIcon(TavliIcons.sparkle),
                        showChevron: true,
                        onTap: () => context.go('/profile/animations'),
                      ),
                    if (kDebugMode)
                      TavliListRow(
                        title: 'Komponente',
                        subtitle: 'Galerija UI biblioteke (samo za razvoj)',
                        leading: const TavliIcon(TavliIcons.checklist),
                        showChevron: true,
                        onTap: () => context.push(componentsPath),
                      ),
                  ],
                ),
              ],
            ),
            const DeleteAccountSection(),
          ],
        ),
      ],
    );
  }
}
