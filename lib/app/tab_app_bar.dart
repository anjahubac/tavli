import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import 'home_shell.dart';

/// Gornja traka glavnih ekrana tabova, kao na platnu: na telefonu naziv
/// „Tavli“ i avatar koji otvara Profil (Android: naslov levo, iOS: u
/// sredini). Na širem ekranu je nema; naslov je u zaglavlju ekrana, a Profil
/// na dnu bočne trake.
class TabAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const TabAppBar({super.key});

  /// Najviša traka sa platna (Android, 64); iOS traka je niža i sama
  /// određuje visinu.
  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaQuery.sizeOf(context).width >= wideLayoutWidth) {
      return const SizedBox.shrink();
    }
    return TavliAppBar(
      initials: profileInitials(ref),
      onProfile: () => context.push('/profile'),
    );
  }
}
