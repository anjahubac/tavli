/// Profil i domaćinstvo prijavljene osobe kako ih vidi server.
class RemoteAccount {
  const RemoteAccount({
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
  final String role;
}

/// Zašto brisanje naloga nije uspelo; na uređaju se tada ništa ne briše.
sealed class DeleteFailure implements Exception {
  const DeleteFailure();

  @override
  String toString() => runtimeType.toString();
}

class DeleteOffline extends DeleteFailure {
  const DeleteOffline();
}

class DeleteServerError extends DeleteFailure {
  const DeleteServerError();
}

class DeleteUnauthorized extends DeleteFailure {
  const DeleteUnauthorized();
}

abstract interface class AccountApi {
  /// Svoj profil, članstvo i domaćinstvo. Baca `AuthFailure`.
  Future<RemoteAccount> fetch();

  /// Edge Function `delete-account`. Baca [DeleteFailure].
  Future<void> deleteAccount();
}
