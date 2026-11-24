import 'dart:async';

import 'package:supabase/supabase.dart';

import '../domain/plan_safety.dart';
import '../domain/planning_tastes.dart';

/// Poziv funkcije `planning-inputs` sa telom zahteva.
typedef PlanningInputsInvoke = Future<FunctionResponse> Function(
  Map<String, Object?> body,
);

/// Ukusi članova sa servera (spec 019 FR-004, ugovor 008). Server bira
/// učesnike i proverava pristanak; aplikacija šalje samo id domaćinstva koje
/// trenutno koristi, da server odbije zahtev ako se domaćinstvo promenilo.
/// Nazivi namirnica se čitaju iz lokalnog kataloga. Ništa se ne kešira.
class RemotePlanningTastes implements PlanningTastesSource {
  RemotePlanningTastes({
    required this.invoke,
    required this.householdId,
    required this.foodNames,
    this.timeout = const Duration(seconds: 10),
  });

  factory RemotePlanningTastes.supabase(
    SupabaseClient client, {
    required String? Function() householdId,
    required Future<Map<String, String>> Function(String householdId) foodNames,
  }) => RemotePlanningTastes(
    householdId: householdId,
    foodNames: foodNames,
    invoke: (body) {
      final token = client.auth.currentSession?.accessToken;
      if (token == null) throw const PlanningTastesDenied();
      return client.functions.invoke(
        'planning-inputs',
        body: body,
        headers: {'Authorization': 'Bearer $token'},
      );
    },
  );

  final PlanningInputsInvoke invoke;
  final String? Function() householdId;
  final Future<Map<String, String>> Function(String householdId) foodNames;
  final Duration timeout;

  @override
  Future<PlanningTastes> current() async {
    final household = householdId();
    // Bez prijave nema ni domaćinstva ni ukusa: običan plan.
    if (household == null) return PlanningTastes.none;
    final Object? data;
    try {
      final response = await invoke({'householdId': household})
          .timeout(timeout);
      if (response.status != 200) throw _error(response.status);
      data = response.data;
    } on FunctionException catch (e) {
      throw _error(e.status);
    } on TimeoutException {
      throw const PlanningTastesUnavailable();
    } on PlanningTastesDenied {
      rethrow;
    } on PlanningTastesUnavailable {
      rethrow;
    } on Object {
      // Mreža ili neispravan odgovor; detalji se ne prikazuju ni ne loguju.
      throw const PlanningTastesUnavailable();
    }
    if (data is! Map<String, Object?>) {
      throw const PlanningTastesUnavailable();
    }
    final PlanningTastes tastes;
    try {
      tastes = PlanningTastes.fromJson(data);
    } on FormatException {
      throw const PlanningTastesUnavailable();
    }
    if (tastes.likedFoodIds.isEmpty && tastes.dislikedFoodIds.isEmpty) {
      return tastes;
    }
    return tastes.withFoodNames(await foodNames(household));
  }

  // 401 (istekla prijava) i 409 (drugo domaćinstvo): plan staje. Ostalo
  // (429, 5xx, nedostupna funkcija) je privremeno: plan bez ukusa.
  static Exception _error(int status) => status == 401 || status == 409
      ? const PlanningTastesDenied()
      : const PlanningTastesUnavailable();
}

/// Najviše recepata u jednoj proveri (isto kao `maxRecipeIds` na serveru).
const maxSafetyRecipeIds = 1000;

/// Provera bezbednosti recepata na serveru (TRELLO-43): ista funkcija
/// `planning-inputs`, uz `recipeIds`. Server sam određuje članove i
/// alergene; odgovor nosi samo da li ograničenja postoje i bezbedne
/// recepte. Ništa se ne kešira.
class RemotePlanSafety implements PlanSafetySource {
  RemotePlanSafety({
    required this.invoke,
    required this.householdId,
    this.timeout = const Duration(seconds: 10),
  });

  factory RemotePlanSafety.supabase(
    SupabaseClient client, {
    required String? Function() householdId,
  }) => RemotePlanSafety(
    householdId: householdId,
    invoke: (body) {
      final token = client.auth.currentSession?.accessToken;
      if (token == null) throw const PlanningTastesDenied();
      return client.functions.invoke(
        'planning-inputs',
        body: body,
        headers: {'Authorization': 'Bearer $token'},
      );
    },
  );

  final PlanningInputsInvoke invoke;
  final String? Function() householdId;
  final Duration timeout;

  @override
  Future<PlanSafety> check(Set<String> recipeIds) async {
    final household = householdId();
    // Bez domaćinstva nema ni članova sa alergijama.
    if (household == null) return const PlanSafety.unrestricted();
    if (recipeIds.length > maxSafetyRecipeIds) {
      throw ArgumentError.value(recipeIds.length, 'recipeIds');
    }
    final Object? data;
    try {
      final response = await invoke({
        'householdId': household,
        'recipeIds': (recipeIds.toList()..sort()),
      }).timeout(timeout);
      if (response.status != 200) throw _safetyError(response.status);
      data = response.data;
    } on FunctionException catch (e) {
      throw _safetyError(e.status);
    } on PlanningTastesDenied {
      rethrow;
    } on PlanSafetyUnavailable {
      rethrow;
    } on Object {
      // Mreža, istek vremena ili neispravan odgovor; detalji se ne loguju.
      throw const PlanSafetyUnavailable();
    }
    if (data is! Map<String, Object?>) throw const PlanSafetyUnavailable();
    try {
      final safety = PlanSafety.fromJson(data);
      // Server sme da vrati samo recepte koje smo pitali.
      if (!recipeIds.containsAll(safety.safeRecipeIds)) {
        throw const FormatException('Nepoznat recept');
      }
      return safety;
    } on FormatException {
      throw const PlanSafetyUnavailable();
    }
  }

  // 401 i 409: plan staje kao kod ukusa. Ostalo: provera nije moguća, pa
  // ni plan (ne zna se da li neko ima alergiju).
  static Exception _safetyError(int status) => status == 401 || status == 409
      ? const PlanningTastesDenied()
      : const PlanSafetyUnavailable();
}
