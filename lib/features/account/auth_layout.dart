import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../providers.dart';
import 'auth_brand.dart';

/// Posle koliko sekundi može ponovo da se pošalje kod ili mejl (FR-005;
/// `max_frequency` u supabase/config.toml).
const resendAfter = Duration(seconds: 30);

/// Kanvas („Predlog: Prijava i registracija“): razmak između delova ekrana
/// i ivica sadržaja.
const _gap = 24.0;
const _top = 32.0;

/// Adresa upisana na „Prijava“ ili „Registracija“, da se ne kuca ponovo
/// posle „Registruj se“, „Prijavi se“ ili „Prijavi se umesto toga“.
final authEmailDraftProvider = NotifierProvider<AuthEmailDraft, String>(
  AuthEmailDraft.new,
);

class AuthEmailDraft extends Notifier<String> {
  @override
  String build() => '';

  void set(String email) => state = email;
}

/// Zajednički raspored ekrana prijave, registracije i imena (kanvas): gore
/// znak ili „Nazad“, pa naslov sa uvodom, sadržaj i dno ekrana. Naslov i
/// prvo polje su na istoj visini na svim ekranima: uvod uvek zauzima
/// najmanje tri reda.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    required this.intro,
    required this.children,
    this.onBack,
    this.footer = const [],
  });

  final String title;

  /// Tekst ispod naslova; podebljani delovi kao `TextSpan` sa `bold`.
  final InlineSpan intro;
  final List<Widget> children;

  /// „Nazad“ umesto znaka gore levo.
  final VoidCallback? onBack;

  /// Dno ekrana (npr. „Nemaš nalog? Registruj se“ ili „Pošalji ponovo“).
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;
    final top = onBack == null
        ? const AuthBrand()
        : Align(
            alignment: AlignmentDirectional.centerStart,
            child: TavliButton.text(
              label: 'Nazad',
              icon: Icons.chevron_left,
              onPressed: onBack,
            ),
          );
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: TavliWidth.dialog,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _gap,
                      TavliSpacing.small,
                      _gap,
                      _gap,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Red gore: visina dugmeta „Nazad“, da se naslov ne
                        // pomera između ekrana sa znakom i sa „Nazad“.
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: top,
                          ),
                        ),
                        const SizedBox(height: _top),
                        _Intro(title: title, intro: intro),
                        for (final child in children) ...[
                          const SizedBox(height: _gap),
                          child,
                        ],
                        const Spacer(),
                        if (footer.isNotEmpty) ...[
                          const SizedBox(height: _gap),
                          ...footer,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.title, required this.intro});

  final String title;
  final InlineSpan intro;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final titleStyle = t.headlineMedium?.copyWith(
      fontSize: 28,
      height: 40 / 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.02 * 28,
      color: c.onSurface,
    );
    final introStyle = t.bodyLarge?.copyWith(
      fontSize: 16,
      height: 1.5,
      color: c.onSurfaceVariant,
    );
    // Naslov, razmak i tri reda uvoda, uz veći sistemski tekst.
    final scaler = MediaQuery.textScalerOf(context);
    final minHeight =
        scaler.scale(28) * 40 / 28 +
        TavliSpacing.small +
        3 * scaler.scale(16) * 1.5;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(header: true, child: Text(title, style: titleStyle)),
          const SizedBox(height: TavliSpacing.small),
          Text.rich(intro, style: introStyle),
        ],
      ),
    );
  }
}

/// Podebljan deo uvoda (adresa, „Potvrdi adresu“).
TextSpan boldSpan(BuildContext context, String text) => TextSpan(
  text: text,
  style: TextStyle(
    fontWeight: FontWeight.w700,
    color: Theme.of(context).colorScheme.onSurface,
  ),
);

/// Pomoćni tekst ispod polja (kanvas: 13, sivo).
class AuthHelperText extends StatelessWidget {
  const AuthHelperText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 13,
      height: 1.4,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// „Nemaš nalog? Registruj se“ i „Već imaš nalog? Prijavi se“ na dnu.
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontSize: 15, color: c.onSurfaceVariant),
        ),
        TavliButton.text(label: action, onPressed: onPressed),
      ],
    );
  }
}

/// Odbrojavanje do ponovnog slanja (30 s od [sentAt]); osvežava ekran svake
/// sekunde dok ne dođe do nule.
mixin ResendCountdown<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _ticker;

  DateTime get sentAt;

  int get secondsLeft {
    final now = ref.read(authClockProvider)();
    final left = resendAfter - now.difference(sentAt);
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  /// Pokreće (ili ponovo pokreće posle novog slanja) odbrojavanje.
  void startCountdown() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {});
      if (secondsLeft == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
