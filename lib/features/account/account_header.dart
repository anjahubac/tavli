import 'package:material_ui/material_ui.dart';

import '../../domain/account.dart';
import '../../sync/sync_engine.dart';

/// Tekst stanja čuvanja u nalogu (FR-018).
String syncStatusText(SyncStatus s) => switch (s) {
  AllSaved() => 'Sve je sačuvano u nalogu.',
  Sending() => 'Čuvam izmene…',
  Waiting(:final count) => 'Čeka slanje: $count',
  Rejected() => 'Neke izmene nisu sačuvane u nalogu.',
};

/// Avatar sa inicijalima na boji iz teme.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.radius = 28});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(
        initials(name),
        style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w600),
      ),
    );
  }
}
