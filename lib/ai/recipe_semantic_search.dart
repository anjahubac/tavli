import 'dart:math' show min;

import 'package:http/http.dart' as http;

import '../data/socket_exception.dart';
import '../domain/recipe.dart';
import '../domain/recipe_search.dart';
import 'ai_errors.dart';
import 'gateway_chat_client.dart';

class EmbeddingServiceUnavailableException implements Exception {
  const EmbeddingServiceUnavailableException();
}

class EmbeddingConnectionException implements Exception {
  const EmbeddingConnectionException();
}

/// Ranks indexed candidates on the server while rendering recipes from Drift.
class IndexedRecipeSearchService {
  const IndexedRecipeSearchService(this._gateway);

  final GatewayChatClient _gateway;

  Future<void> enableIndexing(String householdId) =>
      _gateway.enableRecipeIndexing(householdId);

  Future<List<Recipe>> search({
    required String query,
    required List<Recipe> recipes,
    required RecipeFilter filter,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];
    final candidates = searchRecipes(recipes, filter.copyWith(query: ''));
    final titles = searchRecipes(candidates, filter);
    if (candidates.isEmpty) return titles;
    final byId = {for (final recipe in candidates) recipe.id: recipe};
    final hits = <String, double>{};
    final boundedQuery = String.fromCharCodes(normalizedQuery.runes.take(250));
    final ids = byId.keys.toList(growable: false);
    // Keep each request within the rank_recipe_vectors SQL limit.
    const batchSize = 256;
    try {
      for (var start = 0; start < ids.length; start += batchSize) {
        final batch = ids.sublist(start, min(start + batchSize, ids.length));
        final response = await _gateway.rankRecipes(boundedQuery, batch);
        final matches = response['matches'];
        if (matches is! List<Object?>) {
          throw const FormatException('Neispravan odgovor za pretragu.');
        }
        for (final match in matches) {
          if (match
              case {'recipe_id': final String id, 'distance': final num score}
              when score.isFinite && byId.containsKey(id)) {
            hits[id] = score.toDouble();
          }
        }
      }
    } on SocketException {
      throw const EmbeddingConnectionException();
    } on http.ClientException {
      throw const EmbeddingConnectionException();
    } on TransientError catch (error) {
      if (error.isTimeout) throw const EmbeddingConnectionException();
      rethrow;
    }
    final titleIds = {for (final recipe in titles) recipe.id};
    final ranked = hits.keys.where((id) => !titleIds.contains(id)).toList()
      ..sort((a, b) {
        final distance = hits[a]!.compareTo(hits[b]!);
        return distance != 0 ? distance : a.compareTo(b);
      });
    return [...titles, for (final id in ranked.take(24)) byId[id]!];
  }
}
