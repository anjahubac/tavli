import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../platform.dart';

/// Prečica za ekran na računaru: ⌘ na macOS-u, Ctrl na Windows-u, ili sam
/// taster kad je [command] `false`.
SingleActivator tavliShortcut(
  BuildContext context,
  LogicalKeyboardKey key, {
  bool command = false,
}) {
  final apple = TavliPlatform.of(context).isApple;
  return SingleActivator(
    key,
    meta: command && apple,
    control: command && !apple,
  );
}

/// Oznaka prečice za opis dugmeta, npr. `⌘←` ili `Ctrl+←`; prazna na
/// telefonu, gde nema tastature.
String tavliShortcutHint(
  BuildContext context,
  String key, {
  bool command = false,
}) {
  final platform = TavliPlatform.of(context);
  if (!platform.isDesktop) return '';
  if (!command) return key;
  return platform.isApple ? '⌘$key' : 'Ctrl+$key';
}

/// Dodaje opisu dugmeta prečicu, npr. `Sledeća nedelja (Ctrl+→)`.
String tavliWithShortcut(
  BuildContext context,
  String label,
  String key, {
  bool command = false,
}) {
  final hint = tavliShortcutHint(context, key, command: command);
  return hint.isEmpty ? label : '$label ($hint)';
}

/// Prečice jednog ekrana. Rade dok je fokus negde u ekranu; polja za unos
/// i dugmad prvo obrade svoje tastere (strelice u polju, Enter na dugmetu).
class TavliKeyScope extends StatelessWidget {
  const TavliKeyScope({required this.bindings, required this.child, super.key});

  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: bindings,
    child: Focus(autofocus: true, skipTraversal: true, child: child),
  );
}
