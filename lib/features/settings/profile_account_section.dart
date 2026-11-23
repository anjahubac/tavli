import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/account_api.dart';
import '../../account/auth_controller.dart';
import '../../domain/account.dart';
import '../../providers.dart';
import '../../sync/sync_engine.dart';
import '../account/account_dialogs.dart';
import '../account/account_header.dart' show syncStatusText;
import '../account/auth_error_text.dart';
import '../account/household_join_dialog.dart';
import 'settings_page.dart';

/// Stanje čuvanja u nalogu kao napomena (FR-018).
class SyncStatusNotice extends ConsumerWidget {
  const SyncStatusNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authControllerProvider) case SignedIn(
      membershipVerified: false,
    )) {
      return const TavliNotice(
        message: 'Sinhronizacija čeka proveru članstva.',
        tone: TavliNoticeTone.warning,
      );
    }
    final status = ref.watch(syncStatusProvider).value ?? const AllSaved();
    final tone = switch (status) {
      AllSaved() => TavliNoticeTone.success,
      Sending() => TavliNoticeTone.info,
      Waiting() => TavliNoticeTone.warning,
      Rejected() => TavliNoticeTone.error,
    };
    return TavliNotice(message: syncStatusText(status), tone: tone);
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
    showTavliMessageOn(messenger, deleteErrorText(f));
  }
}

/// Odeljak „Nalog“: avatar, ime, adresa, domaćinstvo, stanje čuvanja i
/// svakodnevne radnje (FR-026).
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! SignedIn) return const SizedBox.shrink();
    final a = auth.account;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final name = a.displayName ?? '';
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: t.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: c.onSurface,
          ),
        ),
        Text(a.email, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
        Text(
          '${a.householdName} · ${a.roleLabel}',
          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
    return SettingsSection(
      title: 'Nalog',
      children: [
        TavliCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TavliSpacing.medium,
            children: [
              // Sa krupnim tekstom ime i adresa prelaze ispod avatara, da
              // dobiju celu širinu i ne lome se usred reči.
              Wrap(
                spacing: TavliSpacing.medium,
                runSpacing: TavliSpacing.small,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TavliAvatar(
                    initials: initials(name),
                    size: TavliAvatar.large,
                  ),
                  details,
                ],
              ),
              const SyncStatusNotice(),
            ],
          ),
        ),
        TavliListGroup(
          children: [
            TavliListRow(
              title: 'Izmeni ime',
              leading: const TavliIcon(TavliIcons.edit),
              onTap: () async {
                final next = await showEditNameDialog(context, name);
                if (next == null) return;
                await ref.read(authControllerProvider.notifier).saveName(next);
              },
            ),
            TavliListRow(
              title: 'Pridruži se domaćinstvu',
              leading: const TavliIcon(TavliIcons.joinHousehold),
              onTap: () => showHouseholdJoinDialog(context),
            ),
            TavliListRow(
              title: 'Odjavi se',
              leading: const TavliIcon(TavliIcons.signOut),
              onTap: () => _signOut(context, ref),
            ),
          ],
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
    return SettingsSection(
      title: 'Brisanje naloga',
      children: [
        TavliListGroup(
          children: [
            TavliListRow(
              title: 'Obriši nalog',
              subtitle: 'Trajno briše nalog i sve podatke',
              leading: const TavliIcon(TavliIcons.delete),
              destructive: true,
              onTap: () => _deleteAccount(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}
