import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../models/chat_message.dart';
import '../models/entry.dart';
import '../services/embedding_search.dart';
import '../services/voyage_service.dart';
import '../services/reminder_service.dart';
import 'entry_provider.dart';
import '../services/tts_service.dart';

final ttsServiceProvider = Provider<TTSService>((ref) => TTSService());

final chatProvider = AsyncNotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);

class ChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  @override
  Future<List<ChatMessage>> build() async {
    return [];
  }

  /// Clear all chat messages and start fresh.
  Future<void> clearChat() async {
    await AppDatabase.instance.clearChatMessages('chat');
    state = const AsyncData([]);
  }

  Future<void> sendMessage(
    String userText, {
    List<File> images = const [],
    bool speakResponse = false,
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

      // Step 2c: Route based on voice vs text mode
      if (speakResponse) {
        // ─── VOICE MODE: Stream response + sentence-by-sentence TTS ───
        final responseStream = aiService.respondToUserStream(
          userText,
          relevantEntries: relevantContext,
          imageDescription: imageDescription,
        );

        final ttsService = ref.read(ttsServiceProvider);
        final spokenText = await ttsService.speakFromStream(responseStream);
        final answerText = spokenText.isNotEmpty ? spokenText : "I hear you 💜";

        // Save AI response
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

        // Still analyze and save as memory in background (non-blocking)
        _saveMemoryInBackground(
          userText: userText,
          imageDescription: imageDescription,
          relevantContext: relevantContext,
          images: images,
        );
      } else {
        // ─── TEXT MODE: Use unified interaction (existing behavior) ────
        final interactionResult = await aiService.processUnifiedInteraction(
          userText,
          imageDescription: imageDescription,
          relevantEntries: relevantContext,
        );

        final isNewMemory =
            interactionResult['is_new_memory'] as bool? ?? false;
        final answerText =
            interactionResult['response_to_user'] as String? ?? "I hear you 💜";

        // Save memory if needed
        if (isNewMemory) {
          await _saveEntryFromResult(
            interactionResult,
            userText: userText,
            images: images,
          );
        }

        // Extract and save reminders (always check, even for questions)
        _saveRemindersFromResult(interactionResult);

        // Save AI response to DB and update state
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
      }
    } catch (e, st) {
      debugPrint('Error in sendMessage: $e');
      debugPrint('Stack trace: $st');

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

  /// Save a structured entry from the AI interaction result.
  Future<void> _saveEntryFromResult(
    Map<String, dynamic> interactionResult, {
    required String userText,
    required List<File> images,
  }) async {
    try {
      final voyageService = ref.read(voyageServiceProvider);
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

      // Refresh entries provider so it appears in the History screen immediately
      ref.read(entriesProvider.notifier).refresh();
    } catch (e) {
      debugPrint('Failed to save memory: $e');
    }
  }

  /// Analyze and save a memory in the background (non-blocking for voice mode).
  void _saveMemoryInBackground({
    required String userText,
    required String imageDescription,
    required List<Map<String, String>> relevantContext,
    required List<File> images,
  }) async {
    try {
      final aiService = ref.read(aiServiceProvider);
      final interactionResult = await aiService.processUnifiedInteraction(
        userText,
        imageDescription: imageDescription,
        relevantEntries: relevantContext,
      );

      final isNewMemory = interactionResult['is_new_memory'] as bool? ?? false;
      if (isNewMemory) {
        await _saveEntryFromResult(
          interactionResult,
          userText: userText,
          images: images,
        );
      }

      // Also extract reminders from voice mode
      _saveRemindersFromResult(interactionResult);
    } catch (e) {
      debugPrint('Background memory save failed: $e');
    }
  }

  /// Extract and save reminders from an AI interaction result.
  void _saveRemindersFromResult(Map<String, dynamic> result) {
    try {
      final reminders = result['reminders'];
      if (reminders != null && reminders is List && reminders.isNotEmpty) {
        final reminderList = reminders
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        ReminderService.instance.saveExtractedReminders(reminderList);
      }
    } catch (e) {
      debugPrint('Failed to extract reminders: $e');
    }
  }
}
