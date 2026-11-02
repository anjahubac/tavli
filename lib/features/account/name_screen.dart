import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/auth_controller.dart';
import '../../domain/account.dart';

/// "Kako da te zovemo?" — obavezan korak posle prve prijave (FR-011).
/// Nema nazad ni preskakanja.
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
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Kako da te zovemo?', style: text.headlineMedium),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(maxNameLength),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Ime',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _valid && !_busy ? _save : null,
                      child: const Text('Nastavi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
