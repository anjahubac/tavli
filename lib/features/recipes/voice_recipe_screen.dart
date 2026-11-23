import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/recipe_format.dart';
import '../../domain/voice_draft.dart';
import 'voice_recipe_flow.dart';

/// „Recept glasom“ (spec 027, TRELLO-91/92): osoba izgovori recept, AI ga
/// upisuje u nacrt, a čuvanje ide kroz ručnu formu posle „Pregledaj recept“.
/// Pitanja agenta su samo tekst; uvek može da se kuca umesto govora.
class VoiceRecipeScreen extends ConsumerStatefulWidget {
  const VoiceRecipeScreen({super.key});

  @override
  ConsumerState<VoiceRecipeScreen> createState() => _VoiceRecipeScreenState();
}

class _VoiceRecipeScreenState extends ConsumerState<VoiceRecipeScreen> {
  late final VoiceRecipeFlow _flow = VoiceRecipeFlow(
    recorder: ref.read(voiceRecorderFactoryProvider)(),
    transcriber: ref.read(speechTranscriberProvider),
    agent: ref.read(voiceAgentProvider),
  );
  final _text = TextEditingController();

  /// Polje trenutno sadrži ispravku poslednjeg prepisa (a ne nov tekst).
  bool _correcting = false;

  @override
  void initState() {
    super.initState();
    _flow.addListener(_sync);
    _text.addListener(() => setState(() {}));
  }

  void _sync() => setState(() {});

  /// „Ispravi“: prepis ide u polje da se izmeni i pošalje umesto prethodnog.
  void _startCorrection() {
    setState(() => _correcting = true);
    _text.text = _flow.transcript ?? '';
  }

  void _stopCorrection() {
    setState(() => _correcting = false);
    _text.clear();
  }

  Future<void> _send() async {
    final text = _text.text;
    if (_correcting) {
      await _flow.correct(text);
    } else {
      await _flow.sendText(text);
    }
    // Poslato bez greške: polje je ponovo za nov tekst.
    if (mounted && _flow.error == null) _stopCorrection();
  }

  @override
  void dispose() {
    _flow
      ..removeListener(_sync)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  void _review() => context.go('/recipes/new/manual', extra: _flow.draft);

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    final draft = flow.draft;
    final status = switch (flow.phase) {
      VoicePhase.recording => 'Snimam… Pritisni „Zaustavi“ kad završiš.',
      VoicePhase.transcribing => 'Prepoznajem govor…',
      VoicePhase.thinking => 'Upisujem u nacrt…',
      VoicePhase.idle => null,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Recept glasom')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(TavliSpacing.large),
                children: [
                  if (status != null) ...[
                    TavliLoading(message: status),
                    const SizedBox(height: TavliSpacing.medium),
                  ],
                  if (flow.error case final error?) ...[
                    TavliNotice(
                      tone: TavliNoticeTone.error,
                      message: error,
                      linkLabel: flow.canRetry ? 'Pokušaj ponovo' : null,
                      onLink: flow.canRetry ? flow.retry : null,
                    ),
                    const SizedBox(height: TavliSpacing.medium),
                  ],
                  if (flow.reply case final reply?) ...[
                    TavliNotice(message: reply),
                    const SizedBox(height: TavliSpacing.medium),
                  ],
                  if (flow.transcript case final heard? when !_correcting) ...[
                    const TavliSectionHeader('Čuo sam'),
                    Text(
                      '„$heard“',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    TavliButtonRow(
                      expand: true,
                      children: [
                        TavliButton.text(
                          label: 'Ispravi',
                          icon: Icons.edit_outlined,
                          onPressed: flow.canCorrect ? _startCorrection : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: TavliSpacing.small),
                  ],
                  TavliSectionHeader(_correcting ? 'Ispravka' : 'Ili ukucaj'),
                  TavliTextField(
                    controller: _text,
                    hint: _correcting
                        ? 'Ispravi prepis pa ga pošalji'
                        : 'npr. „Dodaj kilogram brašna“',
                    enabled: !flow.busy,
                    maxLines: 5,
                  ),
                  const SizedBox(height: TavliSpacing.small),
                  TavliButtonRow(
                    expand: true,
                    children: [
                      if (_correcting)
                        TavliButton.secondary(
                          label: 'Odustani',
                          onPressed: flow.busy ? null : _stopCorrection,
                        ),
                      TavliButton.secondary(
                        label: _correcting
                            ? 'Pošalji ispravku'
                            : 'Pošalji tekst',
                        onPressed: flow.busy || _text.text.trim().isEmpty
                            ? null
                            : _send,
                      ),
                    ],
                  ),
                  const SizedBox(height: TavliSpacing.large),
                  const TavliSectionHeader('Nacrt'),
                  _DraftView(draft),
                  const SizedBox(height: TavliSpacing.small),
                  TavliButtonRow(
                    expand: true,
                    children: [
                      TavliButton.text(
                        label: 'Poništi',
                        onPressed: flow.canUndo ? flow.undo : null,
                      ),
                      TavliButton.text(
                        label: 'Počni ispočetka',
                        onPressed: flow.busy || draft.isEmpty
                            ? null
                            : flow.startOver,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TavliActionBar(
              actions: switch (flow.phase) {
                VoicePhase.recording => [
                  TavliButton.secondary(
                    label: 'Otkaži',
                    onPressed: flow.cancelTurn,
                  ),
                  TavliButton.primary(
                    label: 'Zaustavi',
                    icon: Icons.stop,
                    onPressed: flow.stopAndSend,
                  ),
                ],
                VoicePhase.transcribing || VoicePhase.thinking => [
                  TavliButton.secondary(
                    label: 'Otkaži',
                    onPressed: flow.cancelTurn,
                  ),
                ],
                VoicePhase.idle => [
                  TavliButton.secondary(
                    label: 'Pregledaj recept',
                    onPressed: draft.isEmpty ? null : _review,
                  ),
                  TavliButton.primary(
                    label: 'Govori',
                    icon: Icons.mic_none,
                    onPressed: flow.startRecording,
                  ),
                ],
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftView extends StatelessWidget {
  const _DraftView(this.draft);

  final VoiceDraft draft;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (draft.isEmpty) {
      return Text(
        'Još nema ničega. Pritisni „Govori“ i izgovori naziv, broj porcija, '
        'sastojke i korake, ili ukucaj tekst iznad.',
        style: t.bodyLarge,
      );
    }
    return TavliCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(draft.title ?? 'Bez naziva', style: t.titleMedium),
          if (draft.servings case final n?)
            Text('Porcije: $n', style: t.bodyMedium),
          if (draft.ingredients.isNotEmpty) ...[
            const SizedBox(height: TavliSpacing.small),
            Text('Sastojci', style: t.labelLarge),
            for (final i in draft.ingredients)
              Text('• ${ingredientLine(i)}', style: t.bodyLarge),
          ],
          if (draft.steps.isNotEmpty) ...[
            const SizedBox(height: TavliSpacing.small),
            Text('Priprema', style: t.labelLarge),
            for (final (n, s) in draft.steps.indexed)
              Text('${n + 1}. $s', style: t.bodyLarge),
          ],
        ],
      ),
    );
  }
}
