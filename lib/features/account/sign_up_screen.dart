import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// "Registracija" (nov nalog): e-pošta, pa "Proveri mejl". Mejl za potvrdu
/// ima dugme "Potvrdi adresu" (otvara aplikaciju i prijavljuje) i kod.
class SignUpScreen extends ConsumerWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return auth is ConfirmSent
        ? CheckEmailStep(key: ValueKey(auth.sentAt), sent: auth)
        : const _EmailStep();
  }
}

class _EmailStep extends ConsumerStatefulWidget {
  const _EmailStep();

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

  Future<void> _create() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signUp(_email.text);
    } on AuthFailure catch (f) {
      if (!mounted) return;
      setState(() => _error = f);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toSignIn() {
    ref.read(authEmailDraftProvider.notifier).set(_email.text.trim());
    context.go(signInPath);
  }

  @override
  Widget build(BuildContext context) {
    final invalid = _touched && !_valid;
    final error = _error;
    return AuthPage(
      title: 'Napravi nalog',
      intro: const TextSpan(
        text:
            'Recepti, nabavka i plan obroka čuvaju se na nalogu. Lozinka '
            'nije potrebna.',
      ),
      footer: [
        AuthSwitchLink(
          question: 'Već imaš nalog?',
          action: 'Prijavi se',
          onPressed: _toSignIn,
        ),
      ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TavliSpacing.small - 2,
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
                unawaited(_create());
              },
            ),
            const AuthHelperText('Poslaćemo ti mejl da potvrdiš adresu.'),
          ],
        ),
        TavliButton.primary(
          label: 'Napravi nalog',
          onPressed: _valid && !_busy ? _create : null,
        ),
        if (error is AlreadyRegistered)
          TavliNotice(
            message: alreadyRegisteredTitle,
            linkLabel: signInInsteadText,
            onLink: _toSignIn,
          )
        else if (error != null)
          TavliNotice(
            tone: TavliNoticeTone.error,
            message: authErrorText(error),
          ),
      ],
    );
  }
}

/// "Proveri mejl": dugme "Potvrdi adresu" iz mejla prijavljuje sam (link
/// otvara aplikaciju), ili se upisuje kod iz mejla. "Pošalji mi kod" je za
/// adresu potvrđenu na drugom uređaju.
class CheckEmailStep extends ConsumerStatefulWidget {
  const CheckEmailStep({super.key, required this.sent});

  final ConfirmSent sent;

  @override
  ConsumerState<CheckEmailStep> createState() => _CheckEmailStepState();
}

class _CheckEmailStepState extends ConsumerState<CheckEmailStep>
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

  Future<void> _send(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } on AuthFailure catch (f) {
      if (!mounted) return;
      setState(() => _error = authErrorText(f));
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = secondsLeft;
    final auth = ref.read(authControllerProvider.notifier);
    final platform = TavliPlatform.of(context);
    final linkError = widget.sent.linkError;
    final error =
        _error ?? (linkError == null ? null : authErrorText(linkError));
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return AuthPage(
      title: 'Proveri mejl',
      onBack: auth.changeEmail,
      intro: TextSpan(
        children: [
          const TextSpan(text: 'Poslali smo mejl na '),
          boldSpan(context, widget.sent.email),
          // Windows za sada ne otvara tavli:// linkove (nema instalera),
          // pa samo kod.
          if (defaultTargetPlatform == TargetPlatform.windows)
            const TextSpan(text: '. Upiši ovde kod iz tog mejla.')
          else ...[
            TextSpan(text: platform.isDesktop ? '. Klikni na ' : '. Dodirni '),
            boldSpan(context, 'Potvrdi adresu'),
            const TextSpan(text: ' u mejlu ili upiši kod iz njega.'),
          ],
        ],
      ),
      footer: [
        TavliButton.text(
          label: left == 0
              ? 'Pošalji mejl ponovo'
              : 'Pošalji mejl ponovo (za $left s)',
          onPressed: left == 0 && !_busy
              ? () => _send(auth.resendConfirmation)
              : null,
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
          enabled: !_busy,
          helper: 'Možeš i da nalepiš ceo kod.',
          onChanged: (v) => unawaited(_onChanged(v)),
        ),
        if (_busy) const TavliLoading(),
        if (error case final e?)
          TavliNotice(tone: TavliNoticeTone.error, message: e),
        TavliCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TavliSpacing.small,
            children: [
              Text(
                'Potvrdio/la si adresu na drugom uređaju?',
                style: t.titleSmall?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Pošaljemo ti kod za prijavu i upišeš ga ovde.',
                style: t.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.45,
                  color: c.onSurfaceVariant,
                ),
              ),
              TavliButton.tonal(
                label: 'Pošalji mi kod',
                onPressed: left == 0 && !_busy
                    ? () => _send(auth.sendCodeInstead)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
