import 'package:material_ui/material_ui.dart';

import '../../app/animations/simmering_pot.dart';
import '../../app/placeholder_screen.dart';

/// Početna (021 FR-002): za sada namerno prazna. Kasnije ovde dolaze
/// današnji obroci i obaveštenja (FR-008/009); još nema podataka ni
/// providera.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const EmptyStateScreen(
    art: SimmeringPot(messages: [], size: 120),
    title: 'Ovde će biti današnji obroci',
    body: 'Uskoro: šta se danas kuva i šta treba da uradiš.',
  );
}
