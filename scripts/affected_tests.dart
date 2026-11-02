// Ispisuje test fajlove na koje utiču izmenjeni fajlovi (jedan po redu).
// Prati import/export/part unazad kroz lib/ i test/, pa test vidi i
// posrednu izmenu (npr. widget → ekran → test ekrana). Ispisuje "ALL" kada
// izmena važi za ceo projekat (pubspec, podešavanja testova).
//
// Upotreba: dart run scripts/affected_tests.dart <fajl>...
import 'dart:io';

/// Izmene posle kojih se pokreću svi testovi.
const _everything = {
  'pubspec.yaml',
  'pubspec.lock',
  'analysis_options.yaml',
  'dart_test.yaml',
};

final _directive = RegExp(
  r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

void main(List<String> changed) {
  if (changed.any(_everything.contains)) {
    stdout.writeln('ALL');
    return;
  }

  // Ko zavisi od koga: fajl → fajlovi koji ga uvoze.
  final dependents = <String, Set<String>>{};
  for (final root in ['lib', 'test']) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final from = _normalize(entity.path);
      for (final m in _directive.allMatches(entity.readAsStringSync())) {
        final target = _resolve(from, m.group(1)!);
        if (target != null) {
          dependents.putIfAbsent(target, () => {}).add(from);
        }
      }
    }
  }

  final seen = <String>{};
  final queue = [
    for (final f in changed)
      if (f.endsWith('.dart')) _normalize(f),
  ];
  while (queue.isNotEmpty) {
    final f = queue.removeLast();
    if (!seen.add(f)) continue;
    queue.addAll(dependents[f] ?? const <String>{});
  }

  final tests =
      seen
          .where((f) => f.startsWith('test/') && f.endsWith('_test.dart'))
          .where((f) => File(f).existsSync())
          .toList()
        ..sort();
  tests.forEach(stdout.writeln);
}

/// Putanja fajla na koji pokazuje [uri] iz fajla [from], ili null za
/// spoljne pakete i `dart:` biblioteke.
String? _resolve(String from, String uri) {
  if (uri.startsWith('package:tavli/')) {
    return 'lib/${uri.substring('package:tavli/'.length)}';
  }
  if (uri.contains(':')) return null;
  final dir = from.substring(0, from.lastIndexOf('/') + 1);
  return _normalize('$dir$uri');
}

String _normalize(String path) {
  final parts = <String>[];
  for (final p in path.replaceAll(r'\', '/').split('/')) {
    if (p == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (p.isNotEmpty && p != '.') {
      parts.add(p);
    }
  }
  return parts.join('/');
}
