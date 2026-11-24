import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_recorder.dart';

/// [VoiceRecorder] preko paketa `record`. AAC (m4a), 16 kHz, mono, 64 kbit/s:
/// oko 8 KB u sekundi, pa 120 s staje u 3 MB koje server prima. Gde AAC ne
/// postoji, WAV sa kraćim rokom (90 s ≈ 2,9 MB).
class PlatformVoiceRecorder implements VoiceRecorder {
  PlatformVoiceRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  String? _path;
  bool _aac = true;

  @override
  Duration get maxDuration =>
      _aac ? const Duration(seconds: 120) : const Duration(seconds: 90);

  @override
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    _aac = await _recorder.isEncoderSupported(AudioEncoder.aacLc);
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}${Platform.pathSeparator}tavli_glas_'
        '${DateTime.now().microsecondsSinceEpoch}.${_aac ? 'm4a' : 'wav'}';
    _path = path;
    await _recorder.start(
      RecordConfig(
        encoder: _aac ? AudioEncoder.aacLc : AudioEncoder.wav,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    return true;
  }

  @override
  Future<RecordedClip?> stop() async {
    final path = await _recorder.stop() ?? _path;
    _path = null;
    if (path == null) return null;
    final file = File(path);
    try {
      if (!file.existsSync()) return null;
      return RecordedClip(
        await file.readAsBytes(),
        _aac ? 'audio/mp4' : 'audio/wav',
      );
    } finally {
      // Snimak ostaje samo u memoriji dok se šalje (pravilo 7).
      await _delete(file);
    }
  }

  @override
  Future<void> cancel() async {
    final path = _path;
    _path = null;
    await _recorder.cancel();
    if (path != null) await _delete(File(path));
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }

  static Future<void> _delete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Privremeni folder čisti i sistem.
    }
  }
}
