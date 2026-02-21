import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../models/chat_message.dart';
import '../models/entry.dart';
import '../services/embedding_search.dart';
import '../services/voyage_service.dart';
import 'entry_provider.dart';

final chatProvider = AsyncNotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);

class ChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  @override
  Future<List<ChatMessage>> build() async {
    // 1. Give users a fresh screen on launch (no history loaded here)
    final greeting = ChatMessage(
      id: const Uuid().v4(),
      text:
          "Hey, I'm Emori 💜\n\nI remember everything you've shared with me. Ask me anything about your life — your patterns, your feelings, what you've been going through. I'm here.",
      isUser: false,
      sessionType: 'chat',
      createdAt: DateTime.now(),
    );
    // Don't save the greeting to DB since we want a truly fresh screen next time
    return [greeting];
  }

  Future<void> sendMessage(
    String userText, {
    List<File> images = const [],
  }) async {
    final currentState = state.valueOrNull ?? [];

    // 1. Add and save user message
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      text: userText,
      isUser: true,
      sessionType: 'chat',
      createdAt: DateTime.now(),
      imagePaths: images.map((f) => f.path).toList(),
    );
    await AppDatabase.instance.insertChatMessage(userMsg);
    state = AsyncData([...currentState, userMsg]);

    // 2. Add thinking placeholder (not saved to DB)
    final thinkingId = const Uuid().v4();
    final thinkingMsg = ChatMessage(
      id: thinkingId,
      text: '...',
      isUser: false,
      sessionType: 'chat',
      createdAt: DateTime.now(),
    );
    state = AsyncData([...state.value!, thinkingMsg]);

    try {
      final voyageService = ref.read(voyageServiceProvider);
      final aiService = ref.read(aiServiceProvider);
      final imageService = ref.read(imageServiceProvider);

      // Step 2a: Describe images if any
      String imageDescription = '';
      if (images.isNotEmpty) {
        final descriptions = await Future.wait(
          images.map((img) => imageService.describeImage(img)),
        );
        imageDescription = descriptions.where((d) => d.isNotEmpty).join(' ');
      }

      // Step 2b: Fetch relevant past context
      final queryEmbedding = await voyageService.generateEmbedding(userText);
      final allEntries = await AppDatabase.instance.getAllEntries();
      final relevant = EmbeddingSearch.findMostRelevant(
        queryEmbedding: queryEmbedding,
        allEntries: allEntries,
        topK: 5,
      );

      final relevantContext = relevant
          .map(
            (e) => {
              'date': _formatDate(e.createdAt),
              'summary': e.summary,
              'themes': e.themes.join(', '),
              'emotions': e.emotions.join(', '),
            },
          )
          .toList();

      // Step 2c: Ask AI to route intent (Memory vs Question)
      final interactionResult = await aiService.processUnifiedInteraction(
        userText,
        imageDescription: imageDescription,
        relevantEntries: relevantContext,
      );

      final isNewMemory = interactionResult['is_new_memory'] as bool? ?? false;
      final answerText =
          interactionResult['response_to_user'] as String? ?? "I hear you 💜";

      // Step 2d: If it's a new memory, save it
      if (isNewMemory) {
        try {
          // Re-use voyage for embedding the summary
          final summaryEmbedding = await voyageService.generateEmbedding(
            interactionResult['summary'] as String? ?? userText,
          );

          final entry = Entry(
            id: const Uuid().v4(),
            rawText: userText,
            summary: interactionResult['summary'] as String? ?? userText,
            emotions: List<String>.from(interactionResult['emotions'] ?? []),
            lifeArea: interactionResult['life_area'] as String? ?? 'other',
            type: interactionResult['type'] as String? ?? 'feeling',
            themes: List<String>.from(interactionResult['themes'] ?? []),
            people: List<String>.from(interactionResult['people'] ?? []),
            embeddingBytes: VoyageService.embeddingToBytes(summaryEmbedding),
            imagePaths: images.map((f) => f.path).toList(),
            createdAt: DateTime.now(),
          );
          await AppDatabase.instance.insertEntry(entry);

          // Optionally refresh the entry provider if it's currently being watched
          // ref.invalidate(entriesProvider);
        } catch (e) {
          // Failed to save memory part
        }
      }

      // 3. Save AI response to DB and update state
      final aiMsg = ChatMessage(
        id: thinkingId,
        text: answerText,
        isUser: false,
        sessionType: 'chat',
        createdAt: DateTime.now(),
      );
      await AppDatabase.instance.insertChatMessage(aiMsg);

      final newState = state.value!.map((m) {
        if (m.id == thinkingId) return aiMsg;
        return m;
      }).toList();
      state = AsyncData(newState);
    } catch (e) {
      final errorMsg = ChatMessage(
        id: thinkingId,
        text: 'Something went wrong. Try again 💜',
        isUser: false,
        sessionType: 'chat',
        createdAt: DateTime.now(),
      );
      // Not saving error to DB so it doesn't pollute history permanently

      final newState = state.value!.map((m) {
        if (m.id == thinkingId) return errorMsg;
        return m;
      }).toList();
      state = AsyncData(newState);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
