import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../database/entry_dao.dart';
import '../services/embedding_search.dart';
import 'entry_provider.dart';

// ─── Database Providers ──────────────────────────────────────────

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final entryDaoProvider = Provider<EntryDao>((ref) => EntryDao());

// ─── Chat State ─────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

final chatMessagesProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>(
      (ref) => ChatNotifier(ref),
    );

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;

  ChatNotifier(this.ref) : super([]);

  /// Send a question and get an AI-powered answer from journal entries.
  Future<void> askQuestion(String question) async {
    // Add user message
    state = [...state, ChatMessage(text: question, isUser: true)];

    try {
      final voyage = ref.read(voyageServiceProvider);
      final ai = ref.read(aiServiceProvider);
      final dao = ref.read(entryDaoProvider);

      // 1. Generate embedding for the question
      final queryEmbedding = await voyage.generateEmbedding(question);

      // 2. Find similar entries
      final allEntries = await dao.getAllWithEmbeddings();
      final relevant = EmbeddingSearch.findMostRelevant(
        queryEmbedding: queryEmbedding,
        allEntries: allEntries,
        topK: 5,
      );

      // 3. Format entries as context for AI
      final entriesContext = relevant.map((entry) {
        return {
          'date': _formatDate(entry.createdAt),
          'summary': entry.summary,
          'themes': entry.themes.join(', '),
          'emotions': entry.emotions.join(', '),
        };
      }).toList();

      // 4. Get answer from AI
      final answer = await ai.answerFromMemory(
        userQuestion: question,
        relevantEntries: entriesContext,
      );

      // 5. Add AI response
      state = [...state, ChatMessage(text: answer, isUser: false)];
    } catch (e) {
      state = [
        ...state,
        ChatMessage(
          text: 'Sorry, I had trouble processing that. Please try again.',
          isUser: false,
        ),
      ];
    }
  }

  /// Clear chat history.
  void clear() => state = [];

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
