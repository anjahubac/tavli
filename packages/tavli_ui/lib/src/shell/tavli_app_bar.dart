import 'package:material_ui/material_ui.dart';

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
