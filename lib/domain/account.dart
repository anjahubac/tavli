/// Prijavljena osoba sa svojim domaćinstvom (u 006a tačno jedno).
class Account {
  const Account({
    required this.userId,
    required this.email,
    required this.householdId,
    required this.householdName,
    required this.role,
    this.displayName,
  });

  final String userId;
  final String email;
  final String? displayName;
  final String householdId;
  final String householdName;

  /// `owner` u 006a.
  final String role;

  String get roleLabel => switch (role) {
    'owner' => 'Vlasnik',
    _ => 'Član',
  };

  bool get hasName => displayName != null && displayName!.trim().isNotEmpty;

  Account copyWith({String? displayName}) => Account(
    userId: userId,
    email: email,
    displayName: displayName ?? this.displayName,
    householdId: householdId,
    householdName: householdName,
    role: role,
  );

  @override
  String toString() => 'Account($userId)';
}

/// Najduže ime (posle skidanja razmaka).
const maxNameLength = 40;

/// Prvo slovo prve i poslednje reči, velikim slovima, najviše dva.
String initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '';
  String first(String w) => String.fromCharCode(w.runes.first).toUpperCase();
  if (words.length == 1) return first(words.first);
  return '${first(words.first)}${first(words.last)}';
}

String normalizeEmail(String email) => email.trim().toLowerCase();

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String email) =>
    _emailPattern.hasMatch(normalizeEmail(email));

/// Samo cifre, najviše 6 (kod može da se nalepi kao "123 456").
String normalizeCode(String code) {
  final digits = code.replaceAll(RegExp(r'\D'), '');
  return digits.length > 6 ? digits.substring(0, 6) : digits;
}

/// Ime bez razmaka na krajevima; null kad je prazno ili duže od 40 znakova.
String? normalizeName(String name) {
  final n = name.trim();
  if (n.isEmpty || n.runes.length > maxNameLength) return null;
  return n;
}
