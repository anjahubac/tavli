import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Čiji su podaci: lični podaci pripadaju osobi ([userId]), a podaci
/// domaćinstva domaćinstvu ([householdId]).
class AccountScope {
  const AccountScope({required this.userId, required this.householdId});

  final String userId;
  final String householdId;

  @override
  bool operator ==(Object other) =>
      other is AccountScope &&
      other.userId == userId &&
      other.householdId == householdId;

  @override
  int get hashCode => Object.hash(userId, householdId);

  @override
  String toString() => 'AccountScope($userId, $householdId)';
}

/// Ne odgovara nijednom zapisu (niko nije prijavljen).
const noAccountScope = AccountScope(userId: '', householdId: '');

/// Nalog čiji se podaci prikazuju; null dok niko nije prijavljen.
final accountScopeProvider = Provider<AccountScope?>((ref) => null);
