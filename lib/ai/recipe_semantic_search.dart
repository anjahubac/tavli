import 'dart:io';
import 'dart:math' show min;

import 'package:http/http.dart' as http;

import '../data/recipe_embedding_repository.dart';
import '../domain/recipe.dart';
import '../domain/recipe_search.dart';
import 'ai_errors.dart';
import 'embedding_client.dart';
import 'gateway_chat_client.dart';

class EmbeddingServiceUnavailableException implements Exception {
  const EmbeddingServiceUnavailableException();
}

/// Embeds a query and any changed recipe documents, retaining document vectors
/// in the account-scoped local cache for later searches.
class RecipeSemanticSearchService {
  const RecipeSemanticSearchService({
    required this._client,
    required this._embeddings,
  });

  final OpenAIEmbeddingClient _client;
  final RecipeEmbeddingRepository _embeddings;

  Future<List<Recipe>> search({
    required String query,
    required List<Recipe> recipes,
    required RecipeFilter filter,
  }) async {
    if (query.trim().isEmpty) return const [];
    final candidates = searchRecipes(recipes, filter.copyWith(query: ''));
    final vectors = <String, List<double>>{};
    final uncached = <Recipe>[];
    for (final recipe in candidates) {
      final cached = await _embeddings.getFor(recipe);
      if (cached == null) {
        uncached.add(recipe);
      } else {
        vectors[recipe.id] = cached;
      }
    }
    final batches = _documentBatches(uncached, query.length);
    List<double>? queryVector;
    for (var batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];
      final isLastBatch = batchIndex == batches.length - 1;
      final input = [
        for (final recipe in batch)
          EmbeddingInput(
            text: _boundedRecipeText(recipe),
            taskType: EmbeddingTaskType.retrievalDocument,
          ),
        if (isLastBatch)
          EmbeddingInput(
            text: query,
            taskType: EmbeddingTaskType.retrievalQuery,
          ),
      ];
      final embedded = await _client.embed(input);
      for (var index = 0; index < batch.length; index++) {
        final recipe = batch[index];
        final vector = embedded[index];
        vectors[recipe.id] = vector;
        await _embeddings.save(recipe, vector);
      }
      if (isLastBatch) queryVector = embedded.last;
    }
    queryVector ??= (await _client.embed([
      EmbeddingInput(text: query, taskType: EmbeddingTaskType.retrievalQuery),
    ])).single;
    final titleMatches = searchRecipes(candidates, filter);
    final titleMatchIds = {for (final recipe in titleMatches) recipe.id};
    final semanticMatches = searchSemantically(
      candidates,
      filter,
      queryVector,
      vectors,
    );
    return [
      ...titleMatches,
      for (final recipe in semanticMatches)
        if (!titleMatchIds.contains(recipe.id)) recipe,
    ];
  }

  List<List<Recipe>> _documentBatches(List<Recipe> recipes, int queryLength) {
    if (recipes.isEmpty) return const [];
    final maxDocumentChars = maxEmbeddingTotalLength - queryLength;
    final batches = <List<Recipe>>[];
    var current = <Recipe>[];
    var currentLength = 0;
    for (final recipe in recipes) {
      final text = _boundedRecipeText(recipe);
      if (current.isNotEmpty &&
          (current.length >= maxEmbeddingInputs - 1 ||
              currentLength + text.length > maxDocumentChars)) {
        batches.add(current);
        current = <Recipe>[];
        currentLength = 0;
      }
      current.add(recipe);
      currentLength += text.length;
    }
    if (current.isNotEmpty) batches.add(current);
    return batches;
  }

  String _boundedRecipeText(Recipe recipe) {
    final text = recipeEmbeddingText(recipe);
    return text.length <= maxEmbeddingInputLength
        ? text
        : text.substring(0, maxEmbeddingInputLength);
  }
}

/// Ranks indexed candidates on the server while rendering recipes from Drift.
class IndexedRecipeSearchService {
  const IndexedRecipeSearchService(this._gateway);

  final GatewayChatClient _gateway;

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
