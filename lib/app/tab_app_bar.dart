import 'package:material_ui/material_ui.dart';

import '../features/account/account_header.dart';
import 'home_shell.dart';

/// Gornja traka glavnih ekrana tabova: naziv aplikacije i, na telefonu,
/// avatar. Na širokom ekranu je Profil na dnu bočnog menija. Koji je tab
/// izabran vidi se u donjim tabovima, odnosno u bočnom meniju.
class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    title: const Text('Tavli'),
    automaticallyImplyLeading: false,
    actions: MediaQuery.sizeOf(context).width >= wideLayoutWidth
        ? null
        : const [ProfileButton()],
  );
}
