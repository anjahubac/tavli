import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/account.dart';

/// "Izmeni ime": vraća novo ime ili null ako je odustao.
Future<String?> showEditNameDialog(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (context) => _EditNameDialog(current: current),
    );

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.current});

  final String current;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _name = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = normalizeName(_name.text);
    return TavliDialog<String?>(
      title: 'Izmeni ime',
      content: TavliTextField(
        label: 'Ime',
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        inputFormatters: [LengthLimitingTextInputFormatter(maxNameLength)],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (name != null) Navigator.of(context).pop(name);
        },
      ),
      actions: [
        const TavliDialogAction('Odustani', null),
        TavliDialogAction.computed(
          'Sačuvaj',
          () => normalizeName(_name.text),
          isDefault: true,
          enabled: name != null,
        ),
      ],
    );
  }
}

/// "Odjaviti se?" — true kad je potvrdio. [waiting] = izmene koje još
/// nisu poslate (biće poslate pri sledećoj prijavi na ovom uređaju).
Future<bool> confirmSignOut(BuildContext context, {required int waiting}) =>
    showTavliConfirm(
      context,
      title: 'Odjaviti se?',
      message: [
        'Tvoji podaci ostaju sačuvani u nalogu.',
        if (waiting > 0)
          'Neke izmene još nisu poslate. Poslaćemo ih kada se ponovo '
              'prijaviš na ovom uređaju.',
      ].join('\n\n'),
      cancelLabel: 'Odustani',
      confirmLabel: 'Odjavi se',
    );

/// "Obrisati nalog?" — crveno dugme, bez kucanja potvrde. true = potvrdio.
Future<bool> confirmDeleteAccount(BuildContext context) => showTavliConfirm(
  context,
  title: 'Obrisati nalog?',
  message:
      'Trajno se brišu tvoj profil, domaćinstvo i svi podaci u njemu '
      '(recepti, liste, ostava, planovi, ocene, fotografije), na '
      'serveru i na ovom uređaju, kao i tvoji AI ključevi na ovom '
      'uređaju. Ovo ne može da se poništi.',
  cancelLabel: 'Odustani',
  confirmLabel: 'Obriši nalog',
  destructive: true,
);
