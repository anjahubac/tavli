import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/account_api.dart';
import '../../account/auth_controller.dart';
import '../../account/auth_gateway.dart';
import '../../domain/account.dart';
import '../account/auth_error_text.dart';
import '../account/household_join_dialog.dart';
import '../account/household_providers.dart';
import 'household_edit_dialog.dart';
import 'settings_page.dart';

/// Odeljak „Domaćinstvo“ u profilu (kanvas, varijanta A): kartica sa
/// nazivom koja se otvara na spisak članova, pa radnje. Vlasnik menja
/// domaćinstvo; svaki član deli pozivnicu i može da se pridruži drugom.
class HouseholdSection extends ConsumerStatefulWidget {
  const HouseholdSection({super.key});

  @override
  ConsumerState<HouseholdSection> createState() => _HouseholdSectionState();
}

class _HouseholdSectionState extends ConsumerState<HouseholdSection> {
  var _expanded = false;

  Future<void> _edit(Account account) async {
    final next = await showEditHouseholdDialog(
      context,
      currentName: account.householdName,
      userId: account.userId,
    );
    if (next == null || next == account.householdName || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .renameHousehold(next);
      if (result != RenameHouseholdResult.renamed) {
        showTavliMessageOn(messenger, 'Čuvanje nije uspelo. Pokušaj ponovo.');
      }
    } on AuthFailure catch (failure) {
      showTavliMessageOn(
        messenger,
        failure is Offline
            ? 'Nema interneta. Naziv se menja uz vezu.'
            : authErrorText(failure),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! SignedIn) return const SizedBox.shrink();
    final account = auth.account;
    final members = ref.watch(householdMembersProvider);
    final subtitle = switch (members) {
      AsyncData(:final value) when value.isNotEmpty => memberCountLabel(
        value.length,
      ),
      _ => account.roleLabel,
    };
    return SettingsSection(
      title: 'Domaćinstvo',
      children: [
        TavliListGroup(
          children: [
            Semantics(
              expanded: _expanded,
              child: TavliListRow(
                title: account.householdName,
                subtitle: subtitle,
                leading: const TavliAvatar.icon(
                  TavliIcons.home,
                  size: TavliAvatar.medium,
                ),
                trailing: TavliIcon(
                  _expanded ? TavliIcons.chevronUp : TavliIcons.chevronDown,
                ),
                onTap: () => setState(() => _expanded = !_expanded),
              ),
            ),
            if (_expanded)
              ...switch (members) {
                AsyncData(:final value) => [
                  for (final m in value)
                    HouseholdMemberTile(
                      member: m,
                      isYou: m.userId == account.userId,
                    ),
                ],
                AsyncError() => [const HouseholdMembersError()],
                _ => [const TavliLoading()],
              },
          ],
        ),
        TavliListGroup(
          children: [
            if (account.isOwner)
              TavliListRow(
                title: 'Izmeni domaćinstvo',
                leading: const TavliIcon(TavliIcons.edit),
                showChevron: true,
                onTap: () => _edit(account),
              ),
            TavliListRow(
              title: 'Podeli domaćinstvo',
              subtitle: 'QR kod, kod ili link',
              leading: const TavliIcon(TavliIcons.share),
              showChevron: true,
              onTap: () => context.go('/profile/household-share'),
            ),
            TavliListRow(
              title: 'Pridruži se novom domaćinstvu',
              leading: const TavliIcon(TavliIcons.join),
              showChevron: true,
              onTap: () => showHouseholdChangeDialog(context),
            ),
          ],
        ),
      ],
    );
  }
}
