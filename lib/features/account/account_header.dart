import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../account/account_api.dart';
import '../../account/auth_controller.dart';
import '../../domain/account.dart';
import '../../providers.dart';
import '../../sync/sync_engine.dart';
import 'account_dialogs.dart';
import 'auth_error_text.dart';

/// Tekst stanja čuvanja u nalogu (FR-018).
String syncStatusText(SyncStatus s) => switch (s) {
  AllSaved() => 'Sve je sačuvano u nalogu.',
  Sending() => 'Čuvam izmene…',
  Waiting(:final count) => 'Čeka slanje: $count',
  Rejected() => 'Neke izmene nisu sačuvane u nalogu.',
};

/// Jedan red sa stanjem čuvanja.
class SyncStatusLine extends ConsumerWidget {
  const SyncStatusLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final status = ref.watch(syncStatusProvider).value ?? const AllSaved();
    final (icon, color) = switch (status) {
      AllSaved() => (Icons.cloud_done_outlined, scheme.primary),
      Sending() => (Icons.cloud_upload_outlined, scheme.primary),
      Waiting() => (Icons.cloud_off_outlined, scheme.onSurfaceVariant),
      Rejected() => (Icons.error_outline, scheme.error),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(syncStatusText(status))),
      ],
    );
  }
}

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

Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  final waiting = await ref.read(syncedWriterProvider).unsentCount();
  if (!context.mounted) return;
  if (!await confirmSignOut(context, waiting: waiting)) return;
  await ref.read(authControllerProvider.notifier).signOut();
}

Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
  if (!await confirmDeleteAccount(context)) return;
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(authControllerProvider.notifier).deleteAccount();
  } on DeleteFailure catch (f) {
    messenger.showSnackBar(SnackBar(content: Text(deleteErrorText(f))));
  }
}

/// Vrh "Profila": nalog, domaćinstvo i radnje (FR-026).
class AccountHeader extends ConsumerWidget {
  const AccountHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! SignedIn) return const SizedBox.shrink();
    final a = auth.account;
    final text = Theme.of(context).textTheme;
    final name = a.displayName ?? '';
    final stacked = MediaQuery.textScalerOf(context).scale(16) > 20;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: text.titleLarge),
        Text(a.email, style: text.bodyMedium),
        const SizedBox(height: 4),
        Text('${a.householdName} · ${a.roleLabel}', style: text.bodySmall),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          // Sa velikim tekstom avatar ide iznad, da ime i adresa dobiju
          // celu širinu i ne lome se usred reči.
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InitialsAvatar(name: name),
                    const SizedBox(height: 12),
                    details,
                  ],
                )
              : Row(
                  children: [
                    InitialsAvatar(name: name),
                    const SizedBox(width: 16),
                    Expanded(child: details),
                  ],
                ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SyncStatusLine(),
        ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Izmeni ime'),
          onTap: () async {
            final next = await showEditNameDialog(context, name);
            if (next == null) return;
            await ref.read(authControllerProvider.notifier).saveName(next);
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Odjavi se'),
          onTap: () => _signOut(context, ref),
        ),
      ],
    );
  }
}

/// Dno "Profila": nepovratno brisanje naloga, odvojeno od svakodnevnih
/// radnji (odjava, izmena imena) da se ne dodirne slučajno.
class DeleteAccountSection extends ConsumerWidget {
  const DeleteAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! SignedIn) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Brisanje naloga',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text('Obriši nalog', style: TextStyle(color: scheme.error)),
            subtitle: const Text('Trajno briše nalog i sve podatke'),
            onTap: () => _deleteAccount(context, ref),
          ),
        ],
      ),
    );
  }
}
