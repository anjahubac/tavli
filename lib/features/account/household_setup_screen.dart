import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/account_api.dart';
import '../../account/auth_controller.dart';
import '../../account/auth_gateway.dart';
import '../../account/household_invite_code.dart';
import '../../domain/account.dart';
import 'auth_error_text.dart';
import 'auth_layout.dart';
import 'household_join_dialog.dart';
import 'household_providers.dart';
import 'household_widgets.dart';

/// „Tvoje domaćinstvo“ (kanvas, varijanta C): obavezan korak posle imena.
/// Osoba daje naziv svom domaćinstvu ili se pridružuje postojećem; pozivnica
/// iz linka otvara pridruživanje sa već upisanim kodom. Nema nazad ni
/// preskakanja.
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  final _name = TextEditingController();
  String? _error;
  var _busy = false;
  var _joining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingInvite());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Prazno polje zadržava naziv koji server već daje („Moje domaćinstvo“).
  bool get _valid =>
      _name.text.trim().isEmpty || normalizeHouseholdName(_name.text) != null;

  Future<void> _save() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final name = _name.text.trim().isEmpty ? defaultHouseholdName : _name.text;
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .renameHousehold(name);
      if (!mounted) return;
      if (result != RenameHouseholdResult.renamed) {
        setState(() => _error = 'Čuvanje nije uspelo. Pokušaj ponovo.');
      }
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(
          () => _error = failure is Offline
              ? 'Nema interneta. Za ovaj korak je potrebna veza.'
              : authErrorText(failure),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openPendingInvite() {
    if (!mounted) return;
    final code = ref.read(pendingHouseholdInviteProvider.notifier).take();
    if (code != null) unawaited(_join(code));
  }

  Future<void> _join([HouseholdInviteCode? code]) async {
    if (_joining) return;
    _joining = true;
    try {
      await showHouseholdJoinDialog(
        context,
        code: code,
        origin: HouseholdJoinOrigin.setup,
      );
    } finally {
      _joining = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingHouseholdInviteProvider, (_, code) {
      if (code != null) _openPendingInvite();
    });
    final tooLong = !_valid;
    return PopScope(
      canPop: false,
      child: AuthPage(
        title: 'Tvoje domaćinstvo',
        intro: const TextSpan(
          text:
              'U domaćinstvu deliš plan, nabavku, ostavu i recepte. Daj mu '
              'naziv ili se pridruži domaćinstvu u koje si pozvan.',
        ),
        children: [
          TavliTextField(
            label: 'Naziv domaćinstva',
            hint: defaultHouseholdName,
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [
              LengthLimitingTextInputFormatter(maxHouseholdNameLength),
            ],
            textInputAction: TextInputAction.done,
            errorText: tooLong
                ? 'Naziv može imati najviše $maxHouseholdNameLength znakova.'
                : _error,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
          TavliButton.primary(
            label: 'Nastavi',
            onPressed: _valid && !_busy ? _save : null,
          ),
          const OrDivider(),
          TavliButton.secondary(
            label: 'Pridruži se postojećem domaćinstvu',
            glyph: TavliIcons.join,
            onPressed: _busy ? null : () => unawaited(_join()),
          ),
        ],
      ),
    );
  }
}
