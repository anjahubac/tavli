import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/auth_gateway.dart';
import '../../domain/account.dart';
import '../../providers.dart';
import '../account/auth_error_text.dart';
import '../account/household_providers.dart';

/// „Izmeni domaćinstvo“ (kanvas, samo vlasnik): naziv i članovi sa
/// uklanjanjem. Vraća novi naziv ili `null` ako je odustao; uklanjanje
/// člana se primenjuje odmah, posle potvrde.
Future<String?> showEditHouseholdDialog(
  BuildContext context, {
  required String currentName,
  required String userId,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _EditHouseholdDialog(currentName: currentName, userId: userId),
);

class _EditHouseholdDialog extends ConsumerStatefulWidget {
  const _EditHouseholdDialog({required this.currentName, required this.userId});

  final String currentName;
  final String userId;

  @override
  ConsumerState<_EditHouseholdDialog> createState() =>
      _EditHouseholdDialogState();
}

class _EditHouseholdDialogState extends ConsumerState<_EditHouseholdDialog> {
  late final _name = TextEditingController(text: widget.currentName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _remove(HouseholdMember member) async {
    final name = member.displayName ?? 'Član';
    final confirmed = await showTavliConfirm(
      context,
      title: 'Ukloni člana?',
      message:
          'Da li ste sigurni da želite da uklonite člana $name iz '
          'domaćinstva? Više neće videti zajednički plan, nabavku ni ostavu.',
      cancelLabel: 'Odustani',
      confirmLabel: 'Ukloni',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final status = await ref
          .read(accountServiceProvider)
          .removeHouseholdMember(member.userId);
      if (status != 'removed') {
        showTavliMessageOn(messenger, 'Člana trenutno nije moguće ukloniti.');
      }
    } on AuthFailure catch (failure) {
      showTavliMessageOn(
        messenger,
        failure is Offline
            ? 'Nema interneta. Za uklanjanje je potrebna veza.'
            : authErrorText(failure),
      );
    }
    ref.invalidate(householdMembersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final name = normalizeHouseholdName(_name.text);
    final members = ref.watch(householdMembersProvider);
    return TavliDialog<String?>(
      title: 'Izmeni domaćinstvo',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TavliSpacing.medium,
          children: [
            TavliTextField(
              label: 'Naziv domaćinstva',
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                LengthLimitingTextInputFormatter(maxHouseholdNameLength),
              ],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (name != null) Navigator.of(context).pop(name);
              },
            ),
            const TavliSectionHeader('Članovi'),
            switch (members) {
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, m) in value.indexed) ...[
                    if (i > 0) const TavliDivider(),
                    HouseholdMemberTile(
                      member: m,
                      isYou: m.userId == widget.userId,
                      trailing: m.isOwner || m.userId == widget.userId
                          ? null
                          : TavliIconButton(
                              glyph: TavliIcons.removeMember,
                              semanticLabel:
                                  'Ukloni člana ${m.displayName ?? ''}'.trim(),
                              onPressed: () => _remove(m),
                            ),
                    ),
                  ],
                ],
              ),
              AsyncError() => const HouseholdMembersError(),
              _ => const TavliLoading(),
            },
          ],
        ),
      ),
      actions: [
        const TavliDialogAction('Odustani', null),
        TavliDialogAction.computed(
          'Sačuvaj',
          () => normalizeHouseholdName(_name.text),
          isDefault: true,
          enabled: name != null,
        ),
      ],
    );
  }
}

/// Član u kartici domaćinstva i u „Izmeni domaćinstvo“: inicijali, ime i
/// uloga („Vlasnik · ti“).
class HouseholdMemberTile extends StatelessWidget {
  const HouseholdMemberTile({
    super.key,
    required this.member,
    required this.isYou,
    this.trailing,
  });

  final HouseholdMember member;
  final bool isYou;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final name = member.displayName ?? 'Član bez imena';
    final role = member.isOwner ? 'Vlasnik' : 'Član';
    return TavliListRow(
      title: name,
      subtitle: isYou ? '$role · ti' : role,
      leading: TavliAvatar(initials: initials(member.displayName ?? '')),
      trailing: trailing,
    );
  }
}

/// Članovi nisu stigli sa servera (npr. bez veze).
class HouseholdMembersError extends ConsumerWidget {
  const HouseholdMembersError({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TavliNotice(
    message: 'Članovi trenutno nisu dostupni.',
    tone: TavliNoticeTone.warning,
    linkLabel: 'Pokušaj ponovo',
    onLink: () => ref.invalidate(householdMembersProvider),
  );
}
