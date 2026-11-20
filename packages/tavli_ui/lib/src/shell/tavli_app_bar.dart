import 'package:material_ui/material_ui.dart';

import '../controls/tavli_icon_button.dart';
import '../platform.dart';
import 'shell_parts.dart';

/// Gornja traka glavnih ekrana na telefonu: naziv aplikacije i avatar.
///
/// Android: naslov levo (22, podebljan), avatar 40, visina 64.
/// iOS: naslov u sredini (17), avatar 36, visina 56.
/// Na računaru ekran nema gornju traku (naslov je u `TavliPageHeader`); ako
/// se ipak prikaže, izgleda kao na Androidu.
///
/// Sama dodaje razmak za statusnu traku, pa stoji na vrhu ekrana, iznad
/// sadržaja, a ne u `Scaffold.appBar`.
class TavliAppBar extends StatelessWidget {
  const TavliAppBar({
    super.key,
    this.title = 'Tavli',
    this.initials,
    this.onProfile,
  });

  final String title;

  /// Inicijali u avataru; bez njih traka nema avatar.
  final String? initials;

  /// Dodir na avatar (otvara profil).
  final VoidCallback? onProfile;

  /// Prostor za dodir oko avatara (najmanje 44).
  static const _target = 44.0;

  @override
  Widget build(BuildContext context) {
    final ios = TavliPlatform.of(context) == TavliPlatform.ios;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final titleStyle = ios
        ? t.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.onSurface,
          )
        : t.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.44,
            color: c.onSurface,
          );
    final avatar = initials == null
        ? const SizedBox(width: _target)
        : Semantics(
            button: true,
            label: 'Profil',
            onTap: onProfile,
            excludeSemantics: true,
            child: InkResponse(
              onTap: onProfile,
              radius: _target / 2,
              child: SizedBox.square(
                dimension: _target,
                child: Center(
                  child: ProfileAvatar(
                    initials: initials!,
                    size: ios ? 36 : 40,
                  ),
                ),
              ),
            ),
          );
    final text = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: ios ? TextAlign.center : TextAlign.start,
      style: titleStyle,
    );
    return SafeArea(
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: ios ? 56 : 64),
        child: Padding(
          padding: EdgeInsets.fromLTRB(ios ? 12 : 20, 0, 12, 0),
          child: Row(
            children: [
              if (ios) const SizedBox(width: _target),
              Expanded(child: Semantics(header: true, child: text)),
              avatar,
            ],
          ),
        ),
      ),
    );
  }
}

/// Gornja traka ekrana koji se otvara iznad tabova (Profil, Izgled):
/// dugme nazad i naziv ekrana, bez avatara.
///
/// Android: strelica nazad i naslov levo (22, podebljan), visina 64.
/// iOS: strelica i naziv prethodnog ekrana ([backLabel]) levo, naslov u
/// sredini (17), visina 56.
/// Na širokom ekranu se ne prikazuje: naslov i povratak su u
/// `TavliPageHeader`.
class TavliBackAppBar extends StatelessWidget {
  const TavliBackAppBar({
    super.key,
    required this.title,
    required this.onBack,
    this.backLabel = 'Nazad',
  });

  final String title;
  final VoidCallback onBack;

  /// Naziv prethodnog ekrana, npr. „Profil“ (vidi se samo na iOS-u).
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final ios = TavliPlatform.of(context) == TavliPlatform.ios;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: ios ? TextAlign.center : TextAlign.start,
      style: ios
          ? t.titleMedium?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: c.onSurface,
            )
          : t.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.44,
              color: c.onSurface,
            ),
    );
    final Widget bar;
    if (ios) {
      // Naziv prethodnog ekrana ide levo, a naslov ostaje u sredini: levo i
      // desno su iste širine.
      final back = Semantics(
        button: true,
        label: backLabel == 'Nazad' ? backLabel : 'Nazad na $backLabel',
        excludeSemantics: true,
        child: InkResponse(
          onTap: onBack,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left_rounded, size: 28, color: c.primary),
                Flexible(
                  child: Text(
                    backLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge?.copyWith(
                      fontSize: 17,
                      color: c.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      bar = Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: back,
            ),
          ),
          Expanded(flex: 2, child: Semantics(header: true, child: titleText)),
          const Expanded(child: SizedBox.shrink()),
        ],
      );
    } else {
      bar = Row(
        children: [
          TavliIconButton(
            icon: Icons.arrow_back_rounded,
            semanticLabel: 'Nazad',
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Expanded(child: Semantics(header: true, child: titleText)),
        ],
      );
    }
    return SafeArea(
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: ios ? 56 : 64),
        child: Padding(
          padding: EdgeInsets.fromLTRB(ios ? 8 : 4, 0, ios ? 8 : 12, 0),
          child: bar,
        ),
      ),
    );
  }
}
