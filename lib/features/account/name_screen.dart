import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/auth_controller.dart';
import '../../domain/account.dart';
import 'auth_layout.dart';

/// "Kako da te zovemo?" — obavezan korak samo pri prvoj prijavi (FR-011);
/// ime se čuva na nalogu i posle se menja u profilu. Nema nazad ni
/// preskakanja.
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final _name = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => normalizeName(_name.text) != null;

  Future<void> _save() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).saveName(_name.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AuthPage(
        title: 'Kako da te zovemo?',
        intro: const TextSpan(
          text:
              'Ime vide članovi tvog domaćinstva. Pitamo samo sada, a '
              'kasnije ga menjaš u profilu.',
        ),
        children: [
          TavliTextField(
            label: 'Ime',
            tall: true,
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            inputFormatters: [LengthLimitingTextInputFormatter(maxNameLength)],
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          TavliButton.primary(
            label: 'Nastavi',
            onPressed: _valid && !_busy ? _save : null,
          ),
        ],
      ),
    );
  }
}
