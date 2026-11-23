/// Vreme koje korak pominje („kuvaj 8 minuta“, „1 sat i 30 minuta“,
/// „10-15 min“), za tajmer u režimu kuvanja. Zbir svih pominjanja; za raspon
/// važi veća vrednost. Bez pominjanja vremena (ili preko 24 sata) vraća null.
Duration? stepDuration(String step) {
  var seconds = 0.0;
  for (final m in _pattern.allMatches(step.toLowerCase())) {
    final low = _number(m.group(1)!);
    final high = m.group(2) == null ? low : _number(m.group(2)!);
    final value = high > low ? high : low;
    seconds += value * _unitSeconds(m.group(3)!);
  }
  if (seconds < 1 || seconds > 24 * 3600) return null;
  return Duration(seconds: seconds.round());
}

final _pattern = RegExp(
  r'(\d+(?:[.,]\d+)?)(?:\s*[-–]\s*(\d+(?:[.,]\d+)?))?\s*'
  r'(sati|sata|sat|h|minuta|minute|minut|min|sekundi|sekunde|sekund|sek)'
  r'(?![a-zčćšžđ])',
);

double _number(String s) => double.parse(s.replaceAll(',', '.'));

double _unitSeconds(String unit) => switch (unit) {
  'sati' || 'sata' || 'sat' || 'h' => 3600,
  'minuta' || 'minute' || 'minut' || 'min' => 60,
  _ => 1,
};
