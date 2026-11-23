import 'dart:async';

import 'package:supabase/supabase.dart';

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
