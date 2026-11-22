import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/account_api.dart';
import '../../account/auth_controller.dart';
import '../../account/auth_gateway.dart';
import '../../account/household_invite_code.dart';
import '../../domain/ids.dart';
import '../../providers.dart';
import 'auth_error_text.dart';

Future<void> showHouseholdJoinDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const _HouseholdJoinDialog(),
);

class _HouseholdJoinDialog extends ConsumerStatefulWidget {
  const _HouseholdJoinDialog();

  @override
  ConsumerState<_HouseholdJoinDialog> createState() =>
      _HouseholdJoinDialogState();
}

class _HouseholdJoinDialogState extends ConsumerState<_HouseholdJoinDialog> {
  final _code = TextEditingController();
  HouseholdPreview? _preview;
  JoinRecipeChoice? _choice;
  String? _operationId;
  String? _error;
  StreamSubscription<bool>? _pending;
  Timer? _waitTimer;
  var _busy = false;
  var _waiting = false;
  var _canSkip = false;

  @override
  void dispose() {
    _code.dispose();
    _stopWaiting();
    super.dispose();
  }

  void _stopWaiting() {
    _waitTimer?.cancel();
    unawaited(_pending?.cancel());
    _pending = null;
    _waiting = false;
    _canSkip = false;
  }

  void _startTimer() {
    _waitTimer?.cancel();
    _waitTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _waiting) setState(() => _canSkip = true);
    });
  }

  void _waitForSync() {
    final scope = ref.read(accountScopeProvider);
    if (scope == null) {
      _error = 'Prijavi se ponovo.';
      return;
    }
    _waiting = true;
    _startTimer();
    _pending = ref
        .read(accountServiceProvider)
        .watchPendingHouseholdWrites(scope.userId)
        .listen((waiting) {
          if (mounted && _waiting && !waiting) unawaited(_confirm());
        });
  }

  Future<void> _checkCode() async {
    final code = HouseholdInviteCode.parse(_code.text);
    if (code == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await ref
          .read(accountApiProvider)
          .previewHouseholdJoin(code.value);
      if (mounted) setState(() => _preview = preview);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = _failureText(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm({bool skip = false}) async {
    if (_busy) return;
    setState(() {
      _stopWaiting();
      _busy = true;
      _error = null;
    });
    final preview = _preview!;
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .confirmHouseholdJoin(
            token: _code.text,
            expectedSourceHouseholdId: preview.sourceHouseholdId,
            recipeChoice: _choice!,
            acknowledgeSourceDeletion:
                preview.requiresSourceDeletionAcknowledgement,
            operationId: _operationId ??= newId(),
            sync: ref.read(syncEngineProvider),
            proceedWithoutPendingWrites: skip,
          );
      if (!mounted) return;
      if (result.status == 'joined') {
        Navigator.of(context).pop();
      } else if (result.status == 'pending_sync') {
        setState(_waitForSync);
      } else {
        setState(() {
          if (result.status == 'stale_source' ||
              result.status == 'source_deletion_confirmation_required') {
            _preview = null;
            _choice = null;
            _operationId = null;
          }
          _error = switch (result.status) {
            'stale_source' || 'source_deletion_confirmation_required' =>
              'Članstvo se promenilo. Proveri pozivnicu ponovo.',
            'photo_unavailable' || 'photo_transfer_retry' =>
              'Prenos fotografija još nije uspeo. Pokušaj ponovo.',
            _ => 'Prelazak nije uspeo. Pokušaj ponovo.',
          };
        });
      }
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = _failureText(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _failureText(AuthFailure failure) => switch (failure) {
    Offline() => 'Nema interneta. Za prelazak je potrebna veza.',
    Unavailable() => 'Pozivnica trenutno nije dostupna. Pokušaj ponovo.',
    _ => authErrorText(failure),
  };

  void _select(JoinRecipeChoice choice) {
    setState(() => _choice = choice);
    unawaited(_confirm());
  }

  void _continueWaiting() {
    setState(() => _canSkip = false);
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final waitingMessage = _canSkip
        ? 'Neke izmene u starom domaćinstvu još nisu sačuvane na serveru.'
        : 'Sinhronizujemo izmene…';
    return PopScope(
      canPop: !_busy,
      child: TavliDialog<void>(
        title: 'Pridruži se domaćinstvu',
        actions: [
          TavliDialogAction(
            preview == null ? 'Odustani' : 'Ne, ostani ovde',
            null,
            enabled: !_busy,
          ),
        ],
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TavliSpacing.small,
            children: [
              if (preview == null) ...[
                TavliTextField(
                  label: 'Kod pozivnice',
                  controller: _code,
                  onChanged: (_) => setState(() {}),
                ),
                TavliButton.primary(
                  label: 'Proveri pozivnicu',
                  onPressed:
                      _busy || HouseholdInviteCode.parse(_code.text) == null
                      ? null
                      : _checkCode,
                ),
              ] else ...[
                Text('Prelaziš u domaćinstvo „${preview.householdName}“.'),
                if (_waiting)
                  Semantics(liveRegion: true, child: Text(waitingMessage)),
                if (_canSkip) ...[
                  TavliButton.secondary(
                    label: 'Nastavi da čekaš',
                    onPressed: _continueWaiting,
                  ),
                  TavliButton.destructive(
                    label: 'Pređi bez nesinhronizovanih izmena',
                    onPressed: () => _confirm(skip: true),
                  ),
                ],
                if (!_waiting && !_busy && _choice == null) ...[
                  const Text(
                    'Da li ste sigurni da želite da napustite domaćinstvo?',
                  ),
                  if (preview.requiresSourceDeletionAcknowledgement)
                    const Text(
                      'Poslednji ste član ovog domaćinstva. Ako odete, '
                      'domaćinstvo i podaci koji ostanu u njemu biće trajno obrisani.',
                    ),
                  const Text(
                    'Možeš da poneseš recepte koje si dodao i one bez autora.',
                  ),
                  TavliButton.primary(
                    label: 'Da, ponesi moje recepte',
                    onPressed: () => _select(JoinRecipeChoice.bringRecipes),
                  ),
                  TavliButton.secondary(
                    label: 'Da, bez recepata',
                    onPressed: () => _select(JoinRecipeChoice.leaveRecipes),
                  ),
                ],
                if (!_busy && !_waiting && _choice != null)
                  TavliButton.primary(
                    label: 'Pokušaj ponovo',
                    onPressed: _confirm,
                  ),
              ],
              if (_busy) const LinearProgressIndicator(),
              if (_error case final error?) Text(error),
            ],
          ),
        ),
      ),
    );
  }
}
