import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_errors.dart';
import '../../ai/ai_models.dart';
import '../../ai/speech_transcriber.dart';
import '../../ai/voice_agent.dart';
import '../../domain/voice_draft.dart';
import '../../providers.dart';
import '../settings/ai_error_text.dart';
import 'voice_recorder.dart';

enum VoicePhase { idle, recording, transcribing, thinking }

/// Tok jednog diktata (spec 027): snimak → prepis (server) → agent →
/// provera → nacrt u memoriji. Ništa se ne čuva: recept čuva osoba kroz
/// ručnu formu posle „Pregledaj recept“.
///
/// Svaki izgovor dobija broj; odgovor posle „Otkaži“, novog izgovora ili
/// izlaska sa ekrana se odbacuje, a nacrt se menja samo za verziju za koju
/// je odgovor pripremljen (`VoiceSession`).
class VoiceRecipeFlow extends ChangeNotifier {
  VoiceRecipeFlow({
    required this._recorder,
    required this._transcriber,
    required this._agent,
  });

  final VoiceRecorder _recorder;
  final SpeechTranscriber _transcriber;
  final VoiceAgent _agent;

  VoiceSession _session = VoiceSession();
  VoicePhase _phase = VoicePhase.idle;
  String? _transcript;

  /// Poslednji izgovor je promenio nacrt; ispravka ga prvo poništava.
  bool _lastTurnApplied = false;
  String? _reply;
  String? _error;
  int _turn = 0;
  AICancellation? _cancel;
  Timer? _limit;
  bool _disposed = false;

  VoiceDraft get draft => _session.draft;
  VoicePhase get phase => _phase;
  bool get busy => _phase != VoicePhase.idle;
  bool get canUndo => _session.canUndo && !busy;

  /// Poslednji prepis; može da se ispravi i pošalje ponovo bez snimanja.
  String? get transcript => _transcript;

  /// Poruka ili pitanje agenta (samo tekst).
  String? get reply => _reply;

  /// Greška sa putem dalje (ponovi isti tekst ili kucaj).
  String? get error => _error;
  bool get canRetry => _error != null && (_transcript?.isNotEmpty ?? false);

  /// Prepis može da se ispravi i pošalje umesto prethodnog izgovora.
  bool get canCorrect => !busy && (_transcript?.isNotEmpty ?? false);

  Future<void> startRecording() async {
    if (busy) return;
    _reply = null;
    _error = null;
    final turn = ++_turn;
    final bool allowed;
    try {
      allowed = await _recorder.start();
    } on Object {
      _set(error: 'Snimanje nije uspelo. Možeš da ukucaš tekst.');
      return;
    }
    if (turn != _turn || _disposed) {
      await _recorder.cancel();
      return;
    }
    if (!allowed) {
      _set(error: 'Mikrofon nije dozvoljen. Možeš da ukucaš tekst.');
      return;
    }
    _phase = VoicePhase.recording;
    _limit = Timer(_recorder.maxDuration, () => unawaited(stopAndSend()));
    _notify();
  }

  /// „Zaustavi“: šalje snimak na prepis pa agentu.
  Future<void> stopAndSend() async {
    if (_phase != VoicePhase.recording) return;
    _limit?.cancel();
    final turn = _turn;
    _phase = VoicePhase.transcribing;
    _notify();
    final RecordedClip? clip;
    try {
      clip = await _recorder.stop();
    } on Object {
      _finish(turn, error: 'Snimanje nije uspelo. Možeš da ukucaš tekst.');
      return;
    }
    // „Otkaži“ ili izlazak dok se snimanje zaustavljalo: snimak se ne šalje.
    if (turn != _turn || _disposed) return;
    if (clip == null || clip.bytes.isEmpty) {
      _finish(turn, error: 'Nije ništa snimljeno. Pokušaj ponovo.');
      return;
    }
    final String text;
    try {
      text = await _transcriber.transcribe(clip.bytes, mimeType: clip.mimeType);
    } on TranscriptionError catch (e) {
      _finish(turn, error: transcriptionErrorText(e));
      return;
    }
    if (turn != _turn || _disposed) return;
    _transcript = text;
    if (text.isEmpty) {
      _finish(turn, error: 'Nisam ništa čuo. Pokušaj ponovo ili ukucaj.');
      return;
    }
    await _interpret(text, turn);
  }

  /// Ukucan ili ispravljen tekst ide agentu bez snimanja.
  Future<void> sendText(String text) async {
    final t = text.trim();
    if (busy || t.isEmpty) return;
    _transcript = t;
    await _interpret(t, ++_turn);
  }

  /// Isti prepis ponovo, posle greške agenta (bez novog snimanja).
  /// „Pošalji ispravku“: ispravljen prepis zamenjuje prethodni izgovor.
  /// Ono što je agent uradio sa pogrešnim prepisom se prvo poništi, pa se
  /// izmene ne dupliraju.
  Future<void> correct(String text) async {
    final t = text.trim();
    if (!canCorrect || t.isEmpty) return;
    if (_lastTurnApplied && _session.canUndo) _session.undo();
    _lastTurnApplied = false;
    _transcript = t;
    await _interpret(t, ++_turn);
  }

  Future<void> retry() async {
    final t = _transcript;
    if (busy || t == null || t.isEmpty) return;
    await _interpret(t, ++_turn);
  }

  /// „Otkaži“: prekida snimanje ili zahtev; nacrt ostaje kakav je bio.
  Future<void> cancelTurn() async {
    _turn++;
    _limit?.cancel();
    _cancel?.cancel();
    final wasRecording = _phase == VoicePhase.recording;
    _phase = VoicePhase.idle;
    _notify();
    if (wasRecording) await _recorder.cancel();
  }

  void undo() {
    if (!canUndo) return;
    _session.undo();
    _lastTurnApplied = false;
    _reply = null;
    _notify();
  }

  /// Prazan nacrt, kao na početku.
  void startOver() {
    if (busy) return;
    _session = VoiceSession();
    _transcript = null;
    _lastTurnApplied = false;
    _reply = null;
    _error = null;
    _notify();
  }

  Future<void> _interpret(String text, int turn) async {
    _lastTurnApplied = false;
    _phase = VoicePhase.thinking;
    _reply = null;
    _error = null;
    _notify();
    final base = _session.draft;
    final cancel = _cancel = AICancellation();
    try {
      final result = await _agent.interpret(base, text, cancel: cancel);
      if (turn != _turn || _disposed) return;
      final applied = _session.apply(result.value, baseRevision: base.revision);
      _lastTurnApplied = applied && result.value.actions.isNotEmpty;
      _reply = result.value.reply;
      _finish(turn);
    } on AICancelled {
      return;
    } on TranscriptRejected {
      _finish(turn, error: 'Tekst je predugačak. Podeli ga na više delova.');
    } on AllModelsExhausted catch (e) {
      _finish(turn, error: aiErrorText(e));
    } on AIError catch (e) {
      _finish(turn, error: aiErrorText(e));
    }
  }

  void _finish(int turn, {String? error}) {
    if (turn != _turn || _disposed) return;
    _phase = VoicePhase.idle;
    _error = error;
    _notify();
  }

  void _set({String? error}) {
    _phase = VoicePhase.idle;
    _error = error;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _turn++;
    _limit?.cancel();
    _cancel?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }
}

/// Govor u tekst preko servera; bez Supabase-a nije dostupan.
final speechTranscriberProvider = Provider<SpeechTranscriber>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null
      ? const UnavailableSpeechTranscriber()
      : SupabaseSpeechTranscriber(client);
});

/// Nov snimač za svaki ekran (oslobađa se na izlasku).
final voiceRecorderFactoryProvider = Provider<VoiceRecorder Function()>(
  (ref) => PlatformVoiceRecorder.new,
);

final voiceAgentProvider = Provider<VoiceAgent>(
  (ref) => VoiceAgent(ref.watch(aiRouterProvider)),
);
