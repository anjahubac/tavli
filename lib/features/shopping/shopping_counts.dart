/// Brojevi sa padežima za Nabavku.
library;

/// "1 sastojak", "2 sastojka", "5 sastojaka" (11–14 su "sastojaka").
String ingredientsCount(int n) {
  final lastTwo = n % 100;
  final last = n % 10;
  if (last == 1 && lastTwo != 11) return '$n sastojak';
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return '$n sastojka';
  }
  return '$n sastojaka';
}

/// "1 stavka", "2 stavke", "5 stavki" (11–14 su "stavki").
String itemsCount(int n) {
  final lastTwo = n % 100;
  final last = n % 10;
  if (last == 1 && lastTwo != 11) return '$n stavka';
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return '$n stavke';
  }
  return '$n stavki';
}
