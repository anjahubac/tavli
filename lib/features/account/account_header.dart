import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../account/auth_controller.dart';
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

/// Avatar prijavljenog člana, ili ikonica dok ime nije poznato.
Widget _profileAvatar(WidgetRef ref, double radius) {
  final auth = ref.watch(authControllerProvider);
  final name = auth is SignedIn ? auth.account.displayName ?? '' : '';
  return name.trim().isEmpty
      ? Icon(Icons.account_circle_outlined, size: radius * 2)
      : InitialsAvatar(name: name, radius: radius);
}

/// Avatar gore desno na svakom tabu (telefon); otvara Profil i podešavanja.
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: IconButton(
      tooltip: 'Profil i podešavanja',
      onPressed: () => context.push('/profile'),
      icon: _profileAvatar(ref, 16),
    ),
  );
}

/// Profil na dnu bočnog menija (širok ekran): avatar i „Profil“, pored
/// avatara kad je meni proširen, ispod njega kad je uzan.
class ProfileRailItem extends ConsumerWidget {
  const ProfileRailItem({super.key, required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final avatar = _profileAvatar(ref, 15);
    const label = Text('Profil');
    return Semantics(
      button: true,
      label: 'Profil i podešavanja',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/profile'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DefaultTextStyle.merge(
            style: extended
                ? theme.textTheme.labelLarge
                : theme.textTheme.labelMedium,
            child: extended
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [avatar, const SizedBox(width: 12), label],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [avatar, const SizedBox(height: 4), label],
                  ),
          ),
        ),
      ),
    );
  }
}
