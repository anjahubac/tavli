import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/ai/speech_transcriber.dart';
import 'package:tavli/features/recipes/voice_recipe_flow.dart';
import 'package:tavli/features/recipes/voice_recorder.dart';

import '../../helpers/test_app.dart';

class FakeRecorder implements VoiceRecorder {
  FakeRecorder({this.allowed = true});
  final bool allowed;
  bool disposed = false;

  @override
  Duration get maxDuration => const Duration(minutes: 2);

  @override
  Future<bool> start() async => allowed;

  @override
  Future<RecordedClip?> stop() async =>
      RecordedClip(Uint8List.fromList([1, 2, 3]), 'audio/mp4');

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeTranscriber implements SpeechTranscriber {
  FakeTranscriber(this.text);
  final String text;

  @override
  Future<String> transcribe(
    Uint8List audio, {
    required String mimeType,
  }) async => text;
}

Map<String, dynamic> sarmaTurn() => {
  'actions': [
    {'op': 'set_title', 'title': 'Sarma'},
    {'op': 'set_servings', 'servings': 6},
    {
      'op': 'add_ingredient',
      'name': 'mleveno meso',
      'quantity': 1,
      'unit': 'kg',
    },
    {'op': 'add_step', 'text': 'Umotaj sarmu.'},
  ],
  'reply': 'Upisala sam sarmu.',
};

/// Dodir pa nekoliko frejmova: dok snima ili čeka, indikator se vrti, pa
/// `pumpAndSettle` ne bi stao.
Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pump();
  await tester.tap(find.text(text).last);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testTavli('„Dodaj recept“ nudi unos glasom', (tester) async {
    await pumpTavli(tester);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.text('Glasom'), findsOneWidget);
    await tester.tap(find.text('Glasom'));
    await tester.pumpAndSettle();
    expect(find.text('Recept glasom'), findsOneWidget);
  });

  testTavli('Govori → Zaustavi → nacrt → Pregledaj recept → Sačuvaj', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/voice',
      ai: [aiAnswer(sarmaTurn())],
      overrides: [
        voiceRecorderFactoryProvider.overrideWithValue(FakeRecorder.new),
        speechTranscriberProvider.overrideWithValue(
          FakeTranscriber('Sarma za šest osoba, kilogram mlevenog mesa.'),
        ),
      ],
    );
    expect(find.textContaining('Još nema ničega'), findsOneWidget);

    await tapText(tester, 'Govori');
    expect(find.text('Zaustavi'), findsOneWidget);
    await tapText(tester, 'Zaustavi');

    expect(find.text('Sarma'), findsOneWidget);
    expect(find.text('Porcije: 6'), findsOneWidget);
    expect(find.textContaining('mleveno meso'), findsOneWidget);
    expect(find.text('1. Umotaj sarmu.'), findsOneWidget);
    expect(find.text('Upisala sam sarmu.'), findsOneWidget);
    // Prepis je vidljiv i može da se ispravi.
    expect(
      find.text('Sarma za šest osoba, kilogram mlevenog mesa.'),
      findsOneWidget,
    );

    await tapText(tester, 'Pregledaj recept');
    await tester.pumpAndSettle();
    // Ručna forma popunjena nacrtom; čuva tek osoba.
    expect(await app.titles(), isEmpty);
    await tapButton(tester, 'Sačuvaj');
    expect(await app.titles(), ['Sarma']);
  });

  testTavli('odbijen mikrofon: poruka, a ukucan tekst radi', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/new/voice',
      ai: [aiAnswer(sarmaTurn())],
      overrides: [
        voiceRecorderFactoryProvider.overrideWithValue(
          () => FakeRecorder(allowed: false),
        ),
        speechTranscriberProvider.overrideWithValue(FakeTranscriber('x')),
      ],
    );
    await tapText(tester, 'Govori');
    expect(find.textContaining('Mikrofon nije dozvoljen'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Sarma za šest.');
    await tester.pump();
    await tapText(tester, 'Pošalji tekst');
    expect(find.text('Sarma'), findsOneWidget);
  });

  for (final size in [const Size(320, 640), const Size(1200, 800)]) {
    testTavli('${size.width} px, tekst 2×, tamna tema: bez preliva', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTavli(
        tester,
        size: size,
        location: '/recipes/new/voice',
        ai: [aiAnswer(sarmaTurn())],
        settings: {'theme_mode': 'dark'},
        overrides: [
          voiceRecorderFactoryProvider.overrideWithValue(FakeRecorder.new),
          speechTranscriberProvider.overrideWithValue(FakeTranscriber('x')),
        ],
      );
      await tapText(tester, 'Govori');
      await tapText(tester, 'Zaustavi');
      // Uz 2× tekst nacrt je ispod ekrana; lista ga crta tek kad se skroluje.
      await tester.scrollUntilVisible(
        find.text('Sarma'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Sarma'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
