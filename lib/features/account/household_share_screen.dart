import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/auth_controller.dart';
import '../../account/auth_gateway.dart';
import '../../account/household_invite_code.dart';
import '../../providers.dart';
import '../settings/settings_page.dart';
import 'auth_error_text.dart';
import 'household_providers.dart';

/// „Podeli domaćinstvo“ (kanvas): QR kod, kod pozivnice i slanje. Svaki
/// član deli istu pozivnicu; server proverava članstvo i bez ovog ekrana.
class HouseholdShareScreen extends ConsumerWidget {
  const HouseholdShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invite = ref.watch(householdInviteProvider);
    final (name, isOwner) = switch (ref.watch(authControllerProvider)) {
      SignedIn(:final account) => (account.householdName, account.isOwner),
      _ => ('', false),
    };
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return SettingsPage(
      title: 'Podeli domaćinstvo',
      backLabel: 'Profil',
      fallbackLocation: '/profile',
      children: [
        switch (invite) {
          AsyncData(:final value) => _InviteCard(code: value, name: name),
          AsyncError(:final error) => TavliEmptyState(
            glyph: TavliIcons.share,
            title: 'Pozivnica nije dostupna',
            message: switch (error) {
              Offline() => 'Nema interneta. Pozivnica se prikazuje uz vezu.',
              AuthFailure() => authErrorText(error),
              _ => 'Pozivnica trenutno nije dostupna. Pokušaj ponovo.',
            },
            action: TavliButton.primary(
              label: 'Pokušaj ponovo',
              onPressed: () => ref.invalidate(householdInviteProvider),
            ),
          ),
          _ => const TavliLoading(),
        },
        Text(
          'Pozivnicu može da iskoristi svako ko dobije kod, zato je šalji '
          'samo ljudima s kojima deliš domaćinstvo.',
          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
        if (isOwner && invite is AsyncData)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TavliButton.text(
              label: 'Napravi novu pozivnicu',
              onPressed: () => unawaited(_regenerate(context, ref)),
            ),
          ),
      ],
    );
  }

  /// Vlasnik zamenjuje pozivnicu kada je stari kod otišao pogrešnoj osobi.
  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showTavliConfirm(
      context,
      title: 'Napraviti novu pozivnicu?',
      message:
          'Stari kod, QR i link prestaju da rade. Članovi ostaju u '
          'domaćinstvu.',
      confirmLabel: 'Napravi novu',
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountApiProvider).regenerateHouseholdInvite();
      ref.invalidate(householdInviteProvider);
      showTavliMessageOn(messenger, 'Nova pozivnica je spremna.');
    } on AuthFailure catch (failure) {
      showTavliMessageOn(
        messenger,
        failure is Offline
            ? 'Nema interneta. Nova pozivnica se pravi uz vezu.'
            : 'Nova pozivnica nije napravljena. Pokušaj ponovo.',
      );
    }
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.code, required this.name});

  final HouseholdInviteCode code;
  final String name;

  Uri _link(WidgetRef ref) =>
      code.shareUrl(Uri.parse(ref.read(supabaseConfigProvider).url));

  Future<void> _copy(BuildContext context, String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showTavliMessage(context, done);
  }

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Pozivnica u domaćinstvo',
        text:
            'Pridruži mi se u domaćinstvu „$name“ u aplikaciji Tavli: '
            '${_link(ref)}\nKod pozivnice: ${code.displayValue}',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = isWideSettings(context);
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final qr = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: TavliWidth.qrCode),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TavliRadius.compact),
          // QR je uvek taman na beloj podlozi, i u tamnoj temi, da ga
          // svaka kamera pročita.
          child: QrImageView(
            data: code.qrPayload,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(color: Colors.black),
            dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
            semanticsLabel: 'QR kod pozivnice',
          ),
        ),
      ),
    );
    final copyCode = TavliButton.secondary(
      label: 'Kopiraj kod',
      glyph: TavliIcons.copy,
      onPressed: () => _copy(context, code.displayValue, 'Kod je kopiran.'),
    );
    final details = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      spacing: TavliSpacing.medium,
      children: [
        Column(
          crossAxisAlignment: wide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Semantics(
              header: true,
              child: Text(
                name,
                textAlign: wide ? TextAlign.start : TextAlign.center,
                style: t.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: c.onSurface,
                ),
              ),
            ),
            Text(
              wide
                  ? 'Skeniraj QR telefonom u aplikaciji Tavli. Na računaru '
                        'otvori link ili unesi kod.'
                  : 'Skeniraj QR u aplikaciji Tavli ili unesi kod u '
                        '„Pridruži se domaćinstvu“.',
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: wide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            const TavliSectionHeader('Kod pozivnice'),
            SelectableText(
              code.displayValue,
              style: t.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: c.onSurface,
              ),
            ),
          ],
        ),
        if (wide)
          TavliButtonRow(
            expand: true,
            children: [
              TavliButton.primary(
                label: 'Kopiraj link',
                glyph: TavliIcons.link,
                onPressed: () =>
                    _copy(context, '${_link(ref)}', 'Link je kopiran.'),
              ),
              copyCode,
            ],
          ),
      ],
    );
    if (wide) {
      return TavliCard(
        child: Row(
          spacing: TavliSpacing.large,
          children: [
            Flexible(child: qr),
            Expanded(child: details),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.large,
      children: [
        TavliCard(
          child: Column(spacing: TavliSpacing.medium, children: [qr, details]),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TavliSpacing.small,
          children: [
            Builder(
              builder: (context) => TavliButton.primary(
                label: 'Pošalji pozivnicu',
                glyph: TavliIcons.send,
                onPressed: () => unawaited(_send(context, ref)),
              ),
            ),
            copyCode,
          ],
        ),
      ],
    );
  }
}
