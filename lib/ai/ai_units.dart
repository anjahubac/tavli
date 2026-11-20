/// Rečnik jedinica iz ugovora `recipe.v1`
/// (specs/014-ai-response-contracts/contracts/ai-response-contract.md).
///
/// Ključ je kanonski oblik, vrednost su ostali prepoznati oblici. Služi
/// za listu jedinica u promptu i za oznaku poznata/nepoznata; sastojak
/// uvek čuva jedinicu tačno kako je napisana. Preračunavanje količina
/// pripada nabavci (`normalizeUnit`), ne ovom fajlu.
const aiUnitVocabulary = <String, List<String>>{
  'g': ['gr', 'gram', 'grama'],
  'dkg': ['dag', 'dekagram', 'dekagrama'],
  'kg': ['kilogram', 'kilograma'],
  'ml': ['mililitar', 'mililitara'],
  'dl': ['decilitar', 'decilitara'],
  'l': ['litar', 'litra', 'litara'],
  'kašičica': ['kašičice', 'kasicica', 'kasicice'],
  'kašika': ['kašike', 'kasika', 'kasike'],
  'čaša': ['čaše', 'casa', 'case'],
  'šolja': ['šolje', 'solja', 'solje'],
  'kom': ['kom.', 'komad', 'komada'],
  'glavica': ['glavice'],
  'čen': ['čena', 'čenova'],
  'veza': ['veze', 'vezica', 'vezice'],
  'pakovanje': ['pakovanja'],
  'kesica': ['kesice'],
  'konzerva': ['konzerve'],
  'tegla': ['tegle'],
  'prstohvat': ['prstohvata'],
};

final _byForm = {
  for (final e in aiUnitVocabulary.entries) ...{
    e.key: e.key,
    for (final form in e.value) form: e.key,
  },
};

/// Kanonski oblik jedinice, ili `null` kad je nema ili nije u rečniku
/// (tada je nepoznata i nabavka ne nagađa količinu).
String? canonicalUnit(String? unit) {
  if (unit == null) return null;
  return _byForm[unit.trim().toLowerCase()];
}

/// Kanonske jedinice za prompt, npr. "g, dkg, kg, …".
final aiUnitList = aiUnitVocabulary.keys.join(', ');
