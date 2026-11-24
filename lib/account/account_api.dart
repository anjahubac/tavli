import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../data/socket_exception.dart';
import '../domain/account.dart';
import 'auth_gateway.dart';
import 'household_invite_code.dart';

/// Profil i domaćinstvo prijavljene osobe kako ih vidi server.
class RemoteAccount {
  const RemoteAccount({
    required this.userId,
    required this.email,
    required this.householdId,
    required this.householdName,
    required this.role,
    this.displayName,
    this.householdSetupDone = true,
  });

  final String userId;
  final String email;
  final String? displayName;
  final String householdId;
  final String householdName;
  final String role;

  /// Korak "Tvoje domaćinstvo" je završen (naziv ili pridruživanje).
  final bool householdSetupDone;
}

/// Ishod promene naziva domaćinstva.
enum RenameHouseholdResult { renamed, invalidName, notAllowed }

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

enum JoinRecipeChoice { bringRecipes, leaveRecipes }

class HouseholdPreview {
  const HouseholdPreview({
    required this.householdName,
    required this.sourceHouseholdId,
    required this.requiresSourceDeletionAcknowledgement,
  });

  final String householdName;
  final String sourceHouseholdId;
  final bool requiresSourceDeletionAcknowledgement;
}

class HouseholdJoinResult {
  const HouseholdJoinResult({required this.status, this.account});

  final String status;
  final RemoteAccount? account;
}

abstract interface class AccountApi {
  /// Svoj profil, članstvo i domaćinstvo. Baca `AuthFailure`.
  Future<RemoteAccount> fetch();

  /// Pregled, ažuriranje ili kreiranje trajnog linka domaćinstva (svaki
  /// član).
  Future<String> householdInviteToken();

  /// Vlasnik zamenjuje pozivnicu novom; stari kod, QR i link prestaju da
  /// rade. Vraća novi kod. Baca `AuthFailure`.
  Future<String> regenerateHouseholdInvite();

  /// Pregled linka bez pristupa podacima odredišnog domaćinstva.
  Future<HouseholdPreview> previewHouseholdJoin(String token);

  /// „Kreiraj novo domaćinstvo“: server pravi prazno domaćinstvo sa
  /// nazivom i vraća njegov kod; prelazak ide istim tokom kao
  /// pridruživanje. Baca `AuthFailure`.
  Future<String> prepareNewHousehold(String name);

  /// Potvrda prelaska. Replays use the same operation ID.
  Future<HouseholdJoinResult> confirmHouseholdJoin({
    required String token,
    required String expectedSourceHouseholdId,
    required JoinRecipeChoice recipeChoice,
    required bool acknowledgeSourceDeletion,
    required String operationId,
  });

  /// Vlasnik menja naziv domaćinstva; isti poziv završava korak "Tvoje
  /// domaćinstvo". Baca `AuthFailure`.
  Future<RenameHouseholdResult> renameHousehold(String name);

  /// Članovi sopstvenog domaćinstva (ime i uloga), redom pridruživanja.
  /// Baca `AuthFailure`.
  Future<List<HouseholdMember>> householdMembers();

  /// Vlasnik uklanja člana; server mu pravi novo lično domaćinstvo.
  /// Vraća `removed`, `not_allowed` ili `invalid_request`.
  Future<String> removeHouseholdMember(String memberId);

  /// Da li je nalog uklonjen iz [previousHouseholdId] (server upiše zapis kad
  /// vlasnik ukloni člana, ne kad član sam pređe). Zapis se troši, pa je odgovor
  /// `true` samo jednom. Baca `AuthFailure`.
  Future<bool> takeHouseholdRemoval(String previousHouseholdId);

  /// Edge Function `delete-account`. Baca [DeleteFailure].
  Future<void> deleteAccount();
}

/// Profil i domaćinstvo iz Supabase-a (RLS: samo svoje).
class SupabaseAccountApi implements AccountApi {
  SupabaseAccountApi(
    this._client, {
    this.retryDelay = const Duration(milliseconds: 500),
  });

  final SupabaseClient _client;

  /// Pauza između pokušaja dok okidač na serveru ne napravi domaćinstvo.
  final Duration retryDelay;

  static const _attempts = 3;

  @override
  Future<RemoteAccount> fetch() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const SessionRevoked();
    for (var attempt = 1; ; attempt++) {
      final (profiles, members) = await _guard(
        () async => (
          await _client.rest
              .from('profiles')
              .select('id, email, display_name, household_setup_done')
              .eq('id', uid)
              .limit(1),
          await _client.rest
              .from('household_members')
              .select('household_id, role, households(name)')
              .eq('user_id', uid)
              .limit(1),
        ),
      );
      if (profiles.isNotEmpty && members.isNotEmpty) {
        final p = profiles.first;
        final m = members.first;
        final household = m['households'] as Map<String, dynamic>?;
        return RemoteAccount(
          userId: uid,
          email: p['email'] as String? ?? '',
          displayName: p['display_name'] as String?,
          householdId: m['household_id'] as String,
          householdName: household?['name'] as String? ?? 'Moje domaćinstvo',
          role: m['role'] as String? ?? 'owner',
          householdSetupDone: p['household_setup_done'] as bool? ?? true,
        );
      }
      if (attempt == _attempts) throw const Unavailable();
      await Future<void>.delayed(retryDelay);
    }
  }

  @override
  Future<String> householdInviteToken() => _inviteRpc('household_invite_token');

  @override
  Future<String> regenerateHouseholdInvite() =>
      _inviteRpc('regenerate_household_invite');

  Future<String> _inviteRpc(String function) async {
    try {
      final result = await _client.rpc<Object?>(function);
      if (result is! String || result.isEmpty) throw const Unavailable();
      return result;
    } on PostgrestException catch (e) {
      if (e.code == '401' || (e.code?.startsWith('PGRST3') ?? false)) {
        throw const SessionRevoked();
      }
      throw const Unavailable();
    } on SocketException {
      throw const Offline();
    } on TimeoutException {
      throw const Offline();
    } on http.ClientException {
      throw const Offline();
    }
  }

  @override
  Future<HouseholdPreview> previewHouseholdJoin(String token) async {
    final code = HouseholdInviteCode.parse(token);
    if (code == null) throw const Unavailable();
    final result = await _joinRpc(
      () =>
          _client.rpc('preview_household_join', params: {'token': code.value}),
    );
    return switch (result) {
      {
        'status': 'available',
        'household_name': final String name,
        'source_household_id': final String sourceId,
        'requires_source_deletion_ack': final bool requiresAck,
      } =>
        HouseholdPreview(
          householdName: name,
          sourceHouseholdId: sourceId,
          requiresSourceDeletionAcknowledgement: requiresAck,
        ),
      _ => throw const Unavailable(),
    };
  }

  @override
  Future<HouseholdJoinResult> confirmHouseholdJoin({
    required String token,
    required String expectedSourceHouseholdId,
    required JoinRecipeChoice recipeChoice,
    required bool acknowledgeSourceDeletion,
    required String operationId,
  }) async {
    final code = HouseholdInviteCode.parse(token);
    if (code == null) return const HouseholdJoinResult(status: 'unavailable');
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'household-join',
        body: {
          'token': code.value,
          'expected_source_household_id': expectedSourceHouseholdId,
          'recipe_choice': switch (recipeChoice) {
            JoinRecipeChoice.bringRecipes => 'bring_recipes',
            JoinRecipeChoice.leaveRecipes => 'leave_recipes',
          },
          'source_deletion_ack': acknowledgeSourceDeletion,
          'operation_id': operationId,
        },
      );
    } on FunctionException catch (error) {
      if (error.status == 401) throw const SessionRevoked();
      throw const Unavailable();
    } on SocketException {
      throw const Offline();
    } on TimeoutException {
      throw const Offline();
    } on http.ClientException {
      throw const Offline();
    }
    final result = response.data;
    if (result is! Map) throw const Unavailable();
    final status = result['status'];
    if (status is! String) throw const Unavailable();
    if (status != 'joined') return HouseholdJoinResult(status: status);
    final account = await fetch();
    if (account.householdId != result['household_id']) {
      return const HouseholdJoinResult(status: 'stale_source');
    }
    return HouseholdJoinResult(status: status, account: account);
  }

  @override
  Future<RenameHouseholdResult> renameHousehold(String name) async {
    final result = await _joinRpc(
      () => _client.rpc('rename_household', params: {'name': name}),
    );
    return switch (result['status']) {
      'renamed' => RenameHouseholdResult.renamed,
      'invalid_name' => RenameHouseholdResult.invalidName,
      'not_allowed' => RenameHouseholdResult.notAllowed,
      _ => throw const Unavailable(),
    };
  }

  @override
  Future<List<HouseholdMember>> householdMembers() async {
    final rows = await _guard(
      () => _client.rpc<List<dynamic>>('household_members_overview'),
    );
    return [
      for (final row in rows)
        if (row case {
          'user_id': final String userId,
          'role': final String role,
        })
          HouseholdMember(
            userId: userId,
            role: role,
            displayName: row['display_name'] as String?,
          )
        else
          throw const Unavailable(),
    ];
  }

  @override
  Future<String> prepareNewHousehold(String name) async {
    final result = await _joinRpc(
      () => _client.rpc('prepare_new_household', params: {'name': name}),
    );
    return switch (result) {
      {'status': 'ready', 'token': final String token} when token.isNotEmpty =>
        token,
      _ => throw const Unavailable(),
    };
  }

  @override
  Future<String> removeHouseholdMember(String memberId) async {
    final result = await _joinRpc(
      () => _client.rpc(
        'remove_household_member',
        params: {'member_id': memberId},
      ),
    );
    final status = result['status'];
    if (status is! String) throw const Unavailable();
    return status;
  }

  @override
  Future<bool> takeHouseholdRemoval(String previousHouseholdId) async {
    final result = await _guard(
      () => _client.rpc<dynamic>(
        'take_household_removal',
        params: {'previous_household': previousHouseholdId},
      ),
    );
    if (result is! bool) throw const Unavailable();
    return result;
  }

  Future<Map<String, dynamic>> _joinRpc(
    Future<dynamic> Function() action,
  ) async {
    final result = await _guard(action);
    if (result is! Map) throw const Unavailable();
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-account');
    } on FunctionException catch (e) {
      throw e.status == 401
          ? const DeleteUnauthorized()
          : const DeleteServerError();
    } on SocketException {
      throw const DeleteOffline();
    } on TimeoutException {
      throw const DeleteOffline();
    } on http.ClientException {
      throw const DeleteOffline();
    }
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      final code = e.code ?? '';
      if (code == '401' || code.startsWith('PGRST3')) {
        throw const SessionRevoked();
      }
      throw const Unavailable();
    } on SocketException {
      throw const Offline();
    } on TimeoutException {
      throw const Offline();
    } on http.ClientException {
      throw const Offline();
    }
  }
}

/// Build bez Supabase podešavanja.
class UnconfiguredAccountApi implements AccountApi {
  const UnconfiguredAccountApi();

  @override
  Future<RemoteAccount> fetch() async => throw const Unavailable();

  @override
  Future<String> householdInviteToken() async => throw const Unavailable();

  @override
  Future<String> regenerateHouseholdInvite() async => throw const Unavailable();

  @override
  Future<HouseholdPreview> previewHouseholdJoin(String token) async =>
      throw const Unavailable();

  @override
  Future<String> prepareNewHousehold(String name) async =>
      throw const Unavailable();

  @override
  Future<HouseholdJoinResult> confirmHouseholdJoin({
    required String token,
    required String expectedSourceHouseholdId,
    required JoinRecipeChoice recipeChoice,
    required bool acknowledgeSourceDeletion,
    required String operationId,
  }) async => throw const Unavailable();

  @override
  Future<RenameHouseholdResult> renameHousehold(String name) async =>
      throw const Unavailable();

  @override
  Future<List<HouseholdMember>> householdMembers() async =>
      throw const Unavailable();

  @override
  Future<String> removeHouseholdMember(String memberId) async =>
      throw const Unavailable();

  @override
  Future<bool> takeHouseholdRemoval(String previousHouseholdId) async =>
      throw const Unavailable();

  @override
  Future<void> deleteAccount() async => throw const DeleteServerError();
}
