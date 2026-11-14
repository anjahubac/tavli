import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../account/auth_controller.dart';
import '../../account/auth_gateway.dart';
import '../../domain/account.dart';
import '../../providers.dart';
import 'auth_error_text.dart';

/// Posle koliko sekundi može ponovo da se pošalje kod (FR-005).
const resendAfter = Duration(seconds: 30);

/// "Prijava": e-pošta pa 6-cifreni kod. Bez lozinke; isti tok za nov i
/// postojeći nalog.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final notice = switch (auth) {
      SignedOut(reason: SignOutReason.sessionExpired) => sessionExpiredText,
      SignedOut(reason: SignOutReason.accountDeleted) => accountDeletedText,
      _ => null,
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: auth is CodeSent
                  ? _CodeStep(key: ValueKey(auth.sentAt), sent: auth)
                  : _EmailStep(notice: notice),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailStep extends ConsumerStatefulWidget {
  const _EmailStep({this.notice});

  final String? notice;

  @override
  ConsumerState<_EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends ConsumerState<_EmailStep> {
  final _email = TextEditingController();
  final _focus = FocusNode();
  var _touched = false;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _email.text.isNotEmpty) {
        setState(() => _touched = true);
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _valid => isValidEmail(_email.text);

  Future<void> _send() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).sendCode(_email.text);
    } on AuthFailure catch (f) {
      if (!mounted) return;
      setState(() => _error = authErrorText(f));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final invalid = _touched && !_valid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Prijava', style: text.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Prijavi se e-poštom. Poslaćemo ti kod, lozinka nije potrebna.',
        ),
        if (widget.notice case final n?) ...[
          const SizedBox(height: 16),
          _Notice(n),
        ],
        const SizedBox(height: 24),
        TextField(
          controller: _email,
          focusNode: _focus,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          textInputAction: TextInputAction.send,
          decoration: InputDecoration(
            labelText: 'E-pošta',
            border: const OutlineInputBorder(),
            errorText: invalid ? 'Unesi ispravnu adresu e-pošte.' : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            setState(() => _touched = true);
            unawaited(_send());
          },
        ),
        if (_error case final e?) ...[
          const SizedBox(height: 12),
          _ErrorText(e),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _valid && !_busy ? _send : null,
          child: const Text('Pošalji kod'),
        ),
      ],
    );
  }
}

class _CodeStep extends ConsumerStatefulWidget {
  const _CodeStep({super.key, required this.sent});

  final CodeSent sent;

  @override
  ConsumerState<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends ConsumerState<_CodeStep> {
  final _code = TextEditingController();
  Timer? _ticker;
  var _busy = false;
  String? _error;

  int get _secondsLeft {
    final now = ref.read(authClockProvider)();
    final left = resendAfter - now.difference(widget.sent.sentAt);
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {});
      if (_secondsLeft == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String value) async {
    final code = normalizeCode(value);
    if (code != value) {
      _code.value = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
    }
    if (code.length == 6) await _verify(code);
  }

  Future<void> _verify(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verify(code);
    } on AuthFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _error = authErrorText(f);
        if (f is WrongCode) _code.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .sendCode(widget.sent.email);
    } on AuthFailure catch (f) {
      if (!mounted) return;
      setState(() => _error = authErrorText(f));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final left = _secondsLeft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Prijava', style: text.headlineMedium),
        const SizedBox(height: 8),
        Text('Poslali smo kod na ${widget.sent.email}.'),
        const SizedBox(height: 24),
        TextField(
          controller: _code,
          autofocus: true,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
            LengthLimitingTextInputFormatter(12),
          ],
          style: text.headlineSmall?.copyWith(letterSpacing: 8),
          decoration: const InputDecoration(
            labelText: 'Kod iz poruke',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => unawaited(_onChanged(v)),
        ),
        if (_busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_error case final e?) ...[
          const SizedBox(height: 12),
          _ErrorText(e),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: left == 0 && !_busy ? _resend : null,
          child: Text(
            left == 0 ? 'Pošalji ponovo' : 'Pošalji ponovo za $left s',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : ref.read(authControllerProvider.notifier).changeEmail,
          child: const Text('Promeni e-poštu'),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: Theme.of(context).colorScheme.error));
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
  );
}
