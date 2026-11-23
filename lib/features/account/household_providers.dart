import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/auth_controller.dart';
import '../../account/auth_gateway.dart';
import '../../account/household_invite_code.dart';
import '../../domain/account.dart';
import '../../providers.dart';

/// Članovi domaćinstva prijavljene osobe, sa servera (ime i uloga). Nema
/// keša na uređaju: bez veze ekran prikazuje grešku sa „Pokušaj ponovo“.
/// Baca `AuthFailure`.
final householdMembersProvider =
    FutureProvider.autoDispose<List<HouseholdMember>>((ref) async {
      final scope = ref.watch(accountScopeProvider);
      if (scope == null) return const [];
      // Posle potvrde članstva (npr. kad se veza vrati) učitava se ponovo.
      ref.watch(
        authControllerProvider.select(
          (s) => s is SignedIn && s.membershipVerified,
        ),
      );
      return ref.watch(accountServiceProvider).householdMembers();
    });

/// Trajna pozivnica domaćinstva (samo vlasnik). Baca `AuthFailure`.
final householdInviteProvider = FutureProvider.autoDispose<HouseholdInviteCode>(
  (ref) async {
    ref.watch(accountScopeProvider);
    final token = await ref.watch(accountApiProvider).householdInviteToken();
    final code = HouseholdInviteCode.parse(token);
    if (code == null) throw const Unavailable();
    return code;
  },
);

/// Pozivnica iz linka `tavli://household/join` koja čeka da osoba bude
/// prijavljena (prijava, registracija, ime). Samo u memoriji: posle
/// zatvaranja aplikacije link se otvara ponovo.
final pendingHouseholdInviteProvider =
    NotifierProvider<PendingHouseholdInvite, HouseholdInviteCode?>(
      PendingHouseholdInvite.new,
    );

class PendingHouseholdInvite extends Notifier<HouseholdInviteCode?> {
  @override
  HouseholdInviteCode? build() => null;

  void set(HouseholdInviteCode code) => state = code;

  /// Vraća pozivnicu i briše je, da se tok ne otvori dvaput.
  HouseholdInviteCode? take() {
    final code = state;
    state = null;
    return code;
  }
}
