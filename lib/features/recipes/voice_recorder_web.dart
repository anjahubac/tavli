import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import 'voice_recorder.dart';

/// [VoiceRecorder] u pregledaču (spec 036): WAV, 16 kHz, mono (≈ 2,9 MB za
/// 90 s, server prima do 3 MB). Snimak je blob u memoriji pregledača i čita
/// se pri zaustavljanju; ne ide nigde osim na server za prepis.
class PlatformVoiceRecorder implements VoiceRecorder {
  PlatformVoiceRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  bool _recording = false;

  @override
  Duration get maxDuration => const Duration(seconds: 90);

  @override
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: '',
    );
    _recording = true;
    return true;
  }

  @override
  Future<RecordedClip?> stop() async {
    if (!_recording) return null;
    _recording = false;
    final url = await _recorder.stop();
    if (url == null) return null;
    try {
      return RecordedClip(await http.readBytes(Uri.parse(url)), 'audio/wav');
    } on http.ClientException {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    _recording = false;
    await _recorder.cancel();
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
