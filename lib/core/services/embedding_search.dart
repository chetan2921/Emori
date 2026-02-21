import 'dart:math';
import '../models/entry.dart';
import 'voyage_service.dart';

/// Performs cosine similarity search over stored embeddings to find
/// the most relevant entries for a given query.
class EmbeddingSearch {
  /// Cosine similarity between two vectors.
  static double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// Find top N most relevant entries for a query embedding.
  static List<Entry> findMostRelevant({
    required List<double> queryEmbedding,
    required List<Entry> allEntries,
    int topK = 5,
  }) {
    if (allEntries.isEmpty) return [];

    final scored = allEntries.map((entry) {
      final entryEmbedding = VoyageService.bytesToEmbedding(
        entry.embeddingBytes,
      );
      final score = cosineSimilarity(queryEmbedding, entryEmbedding);
      return MapEntry(entry, score);
    }).toList();

    // Sort by highest similarity
    scored.sort((a, b) => b.value.compareTo(a.value));

    // Return top K
    return scored.take(topK).map((e) => e.key).toList();
  }
}
