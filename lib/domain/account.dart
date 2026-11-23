/// Prijavljena osoba sa svojim domaćinstvom (u 006a tačno jedno).
class Account {
  const Account({
    required this.userId,
    required this.email,
    required this.householdId,
    required this.householdName,
    required this.role,
    this.displayName,
    this.householdReady = true,
  });

  final String userId;
  final String email;
  final String? displayName;
  final String householdId;
  final String householdName;

  /// `owner` ili `member`.
  final String role;

  /// Da li je nalog prošao korak "Tvoje domaćinstvo" (dao naziv ličnom
  /// domaćinstvu ili se pridružio drugom).
  final bool householdReady;

  bool get isOwner => role == 'owner';

  String get roleLabel => switch (role) {
    'owner' => 'Vlasnik',
    _ => 'Član',
  };

  bool get hasName => displayName != null && displayName!.trim().isNotEmpty;

  Account copyWith({
    String? displayName,
    String? householdId,
    String? householdName,
    String? role,
    bool? householdReady,
  }) => Account(
    userId: userId,
    email: email,
    displayName: displayName ?? this.displayName,
    householdId: householdId ?? this.householdId,
    householdName: householdName ?? this.householdName,
    role: role ?? this.role,
    householdReady: householdReady ?? this.householdReady,
  );

  @override
  String toString() => 'Account($userId)';
}

/// Član domaćinstva kako ga vide ostali članovi: ime i uloga, bez e-pošte.
class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.role,
    this.displayName,
  });

  final String userId;
  final String? displayName;
  final String role;

  bool get isOwner => role == 'owner';

  @override
  bool operator ==(Object other) =>
      other is HouseholdMember &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.role == role;

  @override
  int get hashCode => Object.hash(userId, displayName, role);

  @override
  String toString() => 'HouseholdMember($userId)';
}

/// „3 člana“, „1 član“, „5 članova“.
String memberCountLabel(int count) {
  final mod10 = count % 10, mod100 = count % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'član'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'člana'
      : 'članova';
  return '$count $word';
}

/// Najduže ime (posle skidanja razmaka).
const maxNameLength = 40;

/// Najduži naziv domaćinstva (posle skidanja razmaka), isto kao na serveru.
const maxHouseholdNameLength = 40;

/// Naziv koji server daje novom domaćinstvu.
const defaultHouseholdName = 'Moje domaćinstvo';

/// Naziv domaćinstva bez razmaka na krajevima; null kad je prazan ili duži
/// od 40 znakova.
String? normalizeHouseholdName(String name) {
  final n = name.trim();
  if (n.isEmpty || n.runes.length > maxHouseholdNameLength) return null;
  return n;
}

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
