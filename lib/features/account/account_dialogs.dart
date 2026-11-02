import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  void _save() {
    final n = normalizeName(_name.text);
    if (n != null) Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final valid = normalizeName(_name.text) != null;
    return AlertDialog(
      title: const Text('Izmeni ime'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        inputFormatters: [LengthLimitingTextInputFormatter(maxNameLength)],
        decoration: const InputDecoration(labelText: 'Ime'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: valid ? _save : null,
          child: const Text('Sačuvaj'),
        ),
      ],
    );
  }
}

/// "Odjaviti se?" — true kad je potvrdio. [waiting] = izmene koje još
/// nisu poslate (biće poslate pri sledećoj prijavi na ovom uređaju).
Future<bool> confirmSignOut(
  BuildContext context, {
  required int waiting,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Odjaviti se? Tvoji podaci ostaju sačuvani u nalogu.'),
            if (waiting > 0) ...[
              const SizedBox(height: 12),
              const Text(
                'Neke izmene još nisu poslate. Poslaćemo ih kada se ponovo '
                'prijaviš na ovom uređaju.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Odjavi se'),
          ),
        ],
      ),
    ) ??
    false;

/// "Obrisati nalog?" — crveno dugme, bez kucanja potvrde. true = potvrdio.
Future<bool> confirmDeleteAccount(BuildContext context) async {
  final scheme = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Obrisati nalog?'),
          content: const Text(
            'Trajno se brišu tvoj profil, domaćinstvo i svi podaci u njemu '
            '(recepti, liste, ostava, planovi, ocene, fotografije), na '
            'serveru i na ovom uređaju, kao i tvoji AI ključevi na ovom '
            'uređaju. Ovo ne može da se poništi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Obriši nalog'),
            ),
          ],
        ),
      ) ??
      false;
}
