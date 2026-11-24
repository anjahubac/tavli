import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/account_api.dart';
import '../../account/auth_controller.dart';
import '../../account/auth_gateway.dart';
import '../../account/household_invite_code.dart';
import '../../app/home_shell.dart' show wideLayoutWidth;
import '../../domain/account.dart';
import '../../domain/ids.dart';
import '../../providers.dart';
import 'auth_error_text.dart';
import 'household_scan_screen.dart';
import 'household_widgets.dart';

/// Odakle se otvara pridruživanje: profil (napušta se postojeće
/// domaćinstvo) ili korak „Tvoje domaćinstvo“ (novo, prazno lično
/// domaćinstvo se zamenjuje bez pitanja o receptima i brisanju).
enum HouseholdJoinOrigin { profile, setup }

/// Da li uređaj skenira QR kod kamerom (telefon i tablet). Na računaru se
/// kod unosi ili stiže linkom (kanvas: „Pridruži se: kod (bez kamere)“).
bool canScanHouseholdCode(BuildContext context) =>
    !kIsWeb && !TavliPlatform.of(context).isDesktop;

/// „Pridruži se domaćinstvu“: kod (ili QR), pa pregled odredišta i potvrda.
/// [code] je već upisan kada je tok otvoren linkom.
Future<void> showHouseholdJoinDialog(
  BuildContext context, {
  HouseholdInviteCode? code,
  HouseholdJoinOrigin origin = HouseholdJoinOrigin.profile,
}) async {
  final ticket = await _showStep(
    context,
    title: 'Pridruži se domaćinstvu',
    form: (compact) => _JoinCodeForm(initial: code, compact: compact),
  );
  if (ticket == null || !context.mounted) return;
  await _showConfirm(context, ticket, origin);
}

/// Profil > „Pridruži se novom domaćinstvu“: prvo izbor između novog i
/// postojećeg domaćinstva. Novo traži samo naziv; dalje ide isti tok potvrde
/// kao pridruživanje (recepti, poslednji član, sinhronizacija).
Future<void> showHouseholdChangeDialog(BuildContext context) async {
  final choice = await showDialog<_ChangeChoice>(
    context: context,
    builder: (_) => const _ChangeChoiceDialog(),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _ChangeChoice.join:
      await showHouseholdJoinDialog(context);
    case _ChangeChoice.create:
      final ticket = await _showStep(
        context,
        title: 'Novo domaćinstvo',
        form: (compact) => _NewHouseholdForm(compact: compact),
      );
      if (ticket == null || !context.mounted) return;
      await _showConfirm(context, ticket, HouseholdJoinOrigin.profile);
  }
}

Future<void> _showConfirm(
  BuildContext context,
  _JoinTicket ticket,
  HouseholdJoinOrigin origin,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _JoinConfirmDialog(ticket: ticket, origin: origin),
);

/// Kod koji je server prepoznao i šta prelazak znači. [created] je novo
/// domaćinstvo koje je osoba upravo imenovala.
class _JoinTicket {
  const _JoinTicket(this.code, this.preview, {this.created = false});

  final HouseholdInviteCode code;
  final HouseholdPreview preview;
  final bool created;
}

/// Telefon: donji list; širok ekran: dijalog (kanvas).
Future<_JoinTicket?> _showStep(
  BuildContext context, {
  required String title,
  required Widget Function(bool compact) form,
}) {
  final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
  if (!wide) {
    return showTavliSheet<_JoinTicket>(
      context,
      title: title,
      builder: (_) => SingleChildScrollView(child: form(true)),
    );
  }
  return showDialog<_JoinTicket>(
    context: context,
    builder: (_) => TavliDialog<void>(
      title: title,
      actions: const [],
      content: SingleChildScrollView(child: form(false)),
    ),
  );
}

enum _ChangeChoice { create, join }

class _ChangeChoiceDialog extends StatelessWidget {
  const _ChangeChoiceDialog();

  @override
  Widget build(BuildContext context) => TavliDialog<void>(
    title: 'Pridruži se novom domaćinstvu',
    actions: const [],
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TavliSpacing.medium,
        children: [
          TavliButton.primary(
            label: 'Kreiraj novo domaćinstvo',
            glyph: TavliIcons.add,
            onPressed: () => Navigator.of(context).pop(_ChangeChoice.create),
          ),
          TavliButton.secondary(
            label: 'Pridruži se postojećem domaćinstvu',
            glyph: TavliIcons.join,
            onPressed: () => Navigator.of(context).pop(_ChangeChoice.join),
          ),
          TavliButton.text(
            label: 'Odustani',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}

/// Naziv novog domaćinstva. Server pravi prazno domaćinstvo sa kodom, a
/// pregled tog koda daje istu potvrdu kao pridruživanje.
class _NewHouseholdForm extends ConsumerStatefulWidget {
  const _NewHouseholdForm({required this.compact});

  /// Donji list na telefonu: dugmad dele širinu.
  final bool compact;

  @override
  ConsumerState<_NewHouseholdForm> createState() => _NewHouseholdFormState();
}

class _NewHouseholdFormState extends ConsumerState<_NewHouseholdForm> {
  final _name = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _valid => normalizeHouseholdName(_name.text);

  Future<void> _continue() async {
    final name = _valid;
    if (name == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(accountApiProvider);
      final code = HouseholdInviteCode.parse(
        await api.prepareNewHousehold(name),
      );
      if (code == null) throw const Unavailable();
      final preview = await api.previewHouseholdJoin(code.value);
      if (mounted) {
        Navigator.of(context).pop(_JoinTicket(code, preview, created: true));
      }
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(
          () => _error = switch (failure) {
            Offline() =>
              'Nema interneta. Za novo domaćinstvo je potrebna veza.',
            Unavailable() => 'Čuvanje nije uspelo. Pokušaj ponovo.',
            _ => authErrorText(failure),
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: TavliSpacing.medium,
    children: [
      TavliTextField(
        label: 'Naziv domaćinstva',
        hint: defaultHouseholdName,
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [
          LengthLimitingTextInputFormatter(maxHouseholdNameLength),
        ],
        textInputAction: TextInputAction.go,
        errorText: _error,
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _continue(),
      ),
      if (_busy) const LinearProgressIndicator(),
      TavliButtonRow(
        expand: widget.compact,
        alignment: MainAxisAlignment.end,
        children: [
          TavliButton.secondary(
            label: 'Odustani',
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          TavliButton.primary(
            label: 'Nastavi',
            onPressed: _busy || _valid == null ? null : _continue,
          ),
        ],
      ),
    ],
  );
}

String _joinFailureText(AuthFailure failure) => switch (failure) {
  Offline() => 'Nema interneta. Za prelazak je potrebna veza.',
  Unavailable() => 'Pozivnica trenutno nije dostupna. Pokušaj ponovo.',
  _ => authErrorText(failure),
};

class _JoinCodeForm extends ConsumerStatefulWidget {
  const _JoinCodeForm({required this.initial, required this.compact});

  final HouseholdInviteCode? initial;

  /// Donji list na telefonu: dugmad dele širinu.
  final bool compact;

  @override
  ConsumerState<_JoinCodeForm> createState() => _JoinCodeFormState();
}

class _JoinCodeFormState extends ConsumerState<_JoinCodeForm> {
  late final _code = TextEditingController(
    text: widget.initial?.displayValue ?? '',
  );
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  HouseholdInviteCode? get _parsed => HouseholdInviteCode.parse(_code.text);

  Future<void> _continue() async {
    final code = _parsed;
    if (code == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await ref
          .read(accountApiProvider)
          .previewHouseholdJoin(code.value);
      if (mounted) Navigator.of(context).pop(_JoinTicket(code, preview));
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = _joinFailureText(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<HouseholdInviteCode>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const HouseholdScanScreen(),
      ),
    );
    if (code == null || !mounted) return;
    setState(() => _code.text = code.displayValue);
    await _continue();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final scan = canScanHouseholdCode(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.medium,
      children: [
        Text(
          scan
              ? 'Skeniraj QR kod sa telefona člana ili unesi kod pozivnice.'
              : 'Unesi kod pozivnice. Ako otvoriš link iz poruke, kod je '
                    'već upisan.',
          style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
        ),
        if (scan) ...[
          TavliButton.tonal(
            label: 'Skeniraj QR kod',
            glyph: TavliIcons.scan,
            onPressed: _busy ? null : _scan,
          ),
          const OrDivider(),
        ],
        TavliTextField(
          label: 'Kod pozivnice',
          hint: 'XXXX-XXXX-XXXX',
          controller: _code,
          autofocus: !scan,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          textInputAction: TextInputAction.go,
          errorText: _error,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _continue(),
        ),
        if (_busy) const LinearProgressIndicator(),
        TavliButtonRow(
          expand: widget.compact,
          alignment: MainAxisAlignment.end,
          children: [
            TavliButton.secondary(
              label: 'Odustani',
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
            TavliButton.primary(
              label: 'Nastavi',
              onPressed: _busy || _parsed == null ? null : _continue,
            ),
          ],
        ),
      ],
    );
  }
}

/// Faze potvrde: izbor recepata, upozorenje za poslednjeg člana, slanje.
enum _Phase { choose, lastMember, working }

class _JoinConfirmDialog extends ConsumerStatefulWidget {
  const _JoinConfirmDialog({required this.ticket, required this.origin});

  final _JoinTicket ticket;
  final HouseholdJoinOrigin origin;

  @override
  ConsumerState<_JoinConfirmDialog> createState() => _JoinConfirmDialogState();
}

class _JoinConfirmDialogState extends ConsumerState<_JoinConfirmDialog> {
  var _phase = _Phase.choose;
  JoinRecipeChoice? _choice;
  String? _operationId;
  String? _error;
  StreamSubscription<bool>? _pending;
  Timer? _waitTimer;
  var _busy = false;
  var _waiting = false;
  var _canSkip = false;
  var _acknowledged = false;

  bool get _setup => widget.origin == HouseholdJoinOrigin.setup;
  HouseholdPreview get _preview => widget.ticket.preview;

  @override
  void dispose() {
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
    final userId = switch (ref.read(authControllerProvider)) {
      SignedIn(:final account) ||
      NeedsHousehold(:final account) => account.userId,
      _ => null,
    };
    if (userId == null) {
      _error = 'Prijavi se ponovo.';
      return;
    }
    _waiting = true;
    _startTimer();
    _pending = ref
        .read(accountServiceProvider)
        .watchPendingHouseholdWrites(userId)
        .listen((waiting) {
          if (mounted && _waiting && !waiting) unawaited(_confirm());
        });
  }

  void _select(JoinRecipeChoice choice) {
    final warn = _preview.requiresSourceDeletionAcknowledgement && !_setup;
    setState(() {
      _choice = choice;
      _phase = warn ? _Phase.lastMember : _Phase.working;
    });
    if (!warn) unawaited(_confirm());
  }

  Future<void> _confirm({bool skip = false}) async {
    if (_busy) return;
    setState(() {
      _stopWaiting();
      _phase = _Phase.working;
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .confirmHouseholdJoin(
            token: widget.ticket.code.value,
            expectedSourceHouseholdId: _preview.sourceHouseholdId,
            recipeChoice: _choice!,
            // Novo lično domaćinstvo je prazno; njegovo brisanje je deo
            // izbora „Pridruži se“ u koraku „Tvoje domaćinstvo“.
            acknowledgeSourceDeletion:
                _preview.requiresSourceDeletionAcknowledgement &&
                (_setup || _acknowledged),
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
        final stale =
            result.status == 'stale_source' ||
            result.status == 'source_deletion_confirmation_required';
        setState(() {
          _error = switch (result.status) {
            _ when stale => 'Članstvo se promenilo. Proveri pozivnicu ponovo.',
            'photo_unavailable' || 'photo_transfer_retry' =>
              'Prenos fotografija još nije uspeo. Pokušaj ponovo.',
            _ => 'Prelazak nije uspeo. Pokušaj ponovo.',
          };
          // Pregled više ne važi: osoba ponovo otvara pozivnicu.
          if (stale) _choice = null;
        });
      }
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = _joinFailureText(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continueWaiting() {
    setState(() => _canSkip = false);
    _startTimer();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final last = _phase == _Phase.lastMember;
    final caption = widget.ticket.created ? 'Novo domaćinstvo' : 'Pozvan si u';
    const lastTitle = 'Trajno brisanje domaćinstva';
    return PopScope(
      canPop: !_busy,
      child: TavliDialog<void>(
        title: last ? lastTitle : '$caption ${_preview.householdName}',
        header: last
            ? const WarningDialogHeader(title: lastTitle)
            : HouseholdInviteHeader(
                householdName: _preview.householdName,
                caption: caption,
              ),
        actions: const [],
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TavliSpacing.medium,
            children: switch (_phase) {
              _Phase.choose when _setup => _setupChoice(context),
              _Phase.choose => _leaveChoice(context),
              _Phase.lastMember => _lastMember(context),
              _Phase.working => _working(context),
            },
          ),
        ),
      ),
    );
  }

  TextStyle? _body(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge
          ?.copyWith(color: Theme.of(context).colorScheme.onSurface);

  TextStyle? _muted(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  List<Widget> _setupChoice(BuildContext context) => [
    Text(
      'U domaćinstvu delite plan, nabavku, ostavu i recepte.',
      style: _muted(context),
    ),
    TavliButton.primary(
      label: 'Pridruži se',
      glyph: TavliIcons.join,
      onPressed: () => _select(JoinRecipeChoice.leaveRecipes),
    ),
    TavliButton.text(label: 'Odustani', onPressed: _close),
  ];

  List<Widget> _leaveChoice(BuildContext context) {
    final source = switch (ref.read(authControllerProvider)) {
      SignedIn(:final account) => account.householdName,
      _ => null,
    };
    // Kad osoba odlazi kao poslednji član, ništa ne ostaje: to objašnjava
    // sledeći korak („Trajno brisanje domaćinstva“).
    final stays =
        source == null || _preview.requiresSourceDeletionAcknowledgement
        ? ''
        : ' Plan, nabavka i ostava ostaju u domaćinstvu „$source“.';
    return [
      Text(
        'Da li ste sigurni da želite da napustite domaćinstvo?',
        style: _body(context),
      ),
      Text(
        'Možeš da poneseš recepte koje si ti napravio i stare recepte bez '
        'poznatog autora.$stays',
        style: _muted(context),
      ),
      TavliButton.primary(
        label: 'Da, ponesi moje recepte',
        glyph: TavliIcons.recipes,
        onPressed: () => _select(JoinRecipeChoice.bringRecipes),
      ),
      TavliButton.secondary(
        label: 'Da, bez recepata',
        onPressed: () => _select(JoinRecipeChoice.leaveRecipes),
      ),
      TavliButton.text(label: 'Ne, ostani ovde', onPressed: _close),
    ];
  }

  List<Widget> _lastMember(BuildContext context) => [
    Text(
      'Poslednji ste član ovog domaćinstva. Ako odete, domaćinstvo i podaci '
      'koji ostanu u njemu biće trajno obrisani.',
      style: _body(context),
    ),
    MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(TavliRadius.compact),
        onTap: () => setState(() => _acknowledged = !_acknowledged),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Row(
            spacing: TavliSpacing.small,
            children: [
              Checkbox(
                value: _acknowledged,
                onChanged: (v) => setState(() => _acknowledged = v ?? false),
              ),
              Expanded(
                child: Text(
                  'Razumem da je brisanje trajno',
                  style: _body(context)?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    TavliButtonRow(
      expand: true,
      children: [
        TavliButton.secondary(
          label: 'Odustani',
          onPressed: () => setState(() {
            _phase = _Phase.choose;
            _acknowledged = false;
            _choice = null;
          }),
        ),
        TavliButton.destructive(
          label: 'Pridruži se',
          onPressed: _acknowledged ? _confirm : null,
        ),
      ],
    ),
  ];

  List<Widget> _working(BuildContext context) {
    final waitingMessage = _canSkip
        ? 'Neke izmene u starom domaćinstvu još nisu sačuvane na serveru.'
        : 'Sinhronizujemo izmene…';
    return [
      if (_busy) const LinearProgressIndicator(),
      if (_waiting)
        Semantics(
          liveRegion: true,
          child: Text(waitingMessage, style: _body(context)),
        ),
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
      if (_error case final error? when !_busy) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            error,
            style: _body(context)
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ),
        if (_choice != null)
          TavliButton.primary(label: 'Pokušaj ponovo', onPressed: _confirm),
        TavliButton.text(
          label: _setup ? 'Odustani' : 'Ne, ostani ovde',
          onPressed: _close,
        ),
      ],
    ];
  }
}
