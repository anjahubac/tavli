import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/auth_controller.dart';
import '../../account/auth_gateway.dart';
import '../../app/router.dart';
import '../../domain/account.dart';
import 'auth_error_text.dart';
import 'auth_layout.dart';

/// "Prijava" (postojeći nalog): e-pošta, pa "Upiši kod". Bez lozinke.
/// Prijava ne pravi nov nalog; za to je "Registracija" ([signUpPath]).
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    // Nova greška iz mejla ima prednost nad prethodnim razlogom odjave.
    final notice = switch (auth) {
      SignedOut(linkError: final f?) => (
        authErrorText(f),
        TavliNoticeTone.error,
      ),
      SignedOut(reason: SignOutReason.sessionExpired) => (
        sessionExpiredText,
        TavliNoticeTone.info,
      ),
      SignedOut(reason: SignOutReason.accountDeleted) => (
        accountDeletedText,
        TavliNoticeTone.info,
      ),
      SignedOut(reason: SignOutReason.storageUnavailable) => (
        storageUnavailableText,
        TavliNoticeTone.info,
      ),
      _ => null,
    };
    return auth is CodeSent
        ? SignInCodeStep(key: ValueKey(auth.sentAt), sent: auth)
        : _EmailStep(notice: notice);
  }
}

class _EmailStep extends ConsumerStatefulWidget {
  const _EmailStep({this.notice});

  final (String, TavliNoticeTone)? notice;

  @override
  ConsumerState<_EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends ConsumerState<_EmailStep> {
  late final _email = TextEditingController(
    text: ref.read(authEmailDraftProvider),
  );
  final _focus = FocusNode();
  var _touched = false;
  var _busy = false;
  AuthFailure? _error;

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
      setState(() => _error = f);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toSignUp() {
    ref.read(authEmailDraftProvider.notifier).set(_email.text.trim());
    context.go(signUpPath);
  }

  @override
  Widget build(BuildContext context) {
    final invalid = _touched && !_valid;
    final error = _error;
    return AuthPage(
      title: 'Prijava',
      intro: const TextSpan(
        text:
            'Upiši e-poštu naloga i poslaćemo ti kod za prijavu. Lozinka '
            'nije potrebna.',
      ),
      footer: [
        AuthSwitchLink(
          question: 'Nemaš nalog?',
          action: 'Registruj se',
          onPressed: _toSignUp,
        ),
      ],
      children: [
        TavliTextField(
          label: 'E-pošta',
          tall: true,
          controller: _email,
          focusNode: _focus,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          textInputAction: TextInputAction.send,
          errorText: invalid ? 'Unesi ispravnu adresu e-pošte.' : null,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) {
            setState(() => _touched = true);
            unawaited(_send());
          },
        ),
        TavliButton.primary(
          label: 'Pošalji kod',
          onPressed: _valid && !_busy ? _send : null,
        ),
        if (error is NoAccount)
          const TavliNotice(
            tone: TavliNoticeTone.error,
            title: noAccountTitle,
            message: noAccountText,
          )
        else if (error != null)
          TavliNotice(
            tone: TavliNoticeTone.error,
            message: authErrorText(error),
          )
        else if (widget.notice case (final message, final tone))
          TavliNotice(tone: tone, message: message),
      ],
    );
  }
}

/// "Upiši kod": 6-cifreni kod iz mejla za prijavu.
class SignInCodeStep extends ConsumerStatefulWidget {
  const SignInCodeStep({super.key, required this.sent});

  final CodeSent sent;

  @override
  ConsumerState<SignInCodeStep> createState() => _SignInCodeStepState();
}

class _SignInCodeStepState extends ConsumerState<SignInCodeStep>
    with ResendCountdown {
  final _code = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  DateTime get sentAt => widget.sent.sentAt;

  @override
  void initState() {
    super.initState();
    startCountdown();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String code) async {
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
    final left = secondsLeft;
    final auth = ref.read(authControllerProvider.notifier);
    return AuthPage(
      title: 'Upiši kod',
      onBack: auth.changeEmail,
      intro: TextSpan(
        children: [
          const TextSpan(text: 'Poslali smo kod na '),
          boldSpan(context, widget.sent.email),
          const TextSpan(text: '. Važi 10 minuta.'),
        ],
      ),
      footer: [
        TavliButton.text(
          label: left == 0 ? 'Pošalji ponovo' : 'Pošalji ponovo (za $left s)',
          onPressed: left == 0 && !_busy ? _resend : null,
        ),
        TavliButton.text(
          label: 'Promeni e-poštu',
          onPressed: _busy ? null : auth.changeEmail,
        ),
      ],
      children: [
        TavliCodeField(
          label: 'Kod iz poruke',
          controller: _code,
          autofocus: true,
          enabled: !_busy,
          helper: 'Možeš i da nalepiš ceo kod. Proverava se sam čim je upisan.',
          onChanged: (v) => unawaited(_onChanged(v)),
        ),
        if (_busy) const TavliLoading(),
        if (_error case final e?)
          TavliNotice(tone: TavliNoticeTone.error, message: e),
      ],
    );
  }
}
