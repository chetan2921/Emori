import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'entry_provider.dart';

// ─── Emotion Frequency Charting ───────────────────────────────────────────────

final emotionFrequencyProvider = FutureProvider<Map<String, int>>((ref) async {
  final entries = await AppDatabase.instance.getEntriesFromLastDays(30);
  final Map<String, int> frequencies = {};

  for (final entry in entries) {
    for (final emotion in entry.emotions) {
      final key = emotion.toLowerCase().trim();
      if (key.isNotEmpty) {
        frequencies[key] = (frequencies[key] ?? 0) + 1;
      }
    }
  }

  // Sort by frequency descending and take top 5
  final sortedEntries = frequencies.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Map.fromEntries(sortedEntries.take(5));
});

// ─── Pattern Detection ───────────────────────────────────────────

final patternsProvider = AsyncNotifierProvider<PatternsNotifier, String?>(
  PatternsNotifier.new,
);

class PatternsNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<void> analyze() async {
    state = const AsyncLoading();
    try {
      final entries = await AppDatabase.instance.getEntriesFromLastDays(30);

      if (entries.isEmpty) {
        state = const AsyncData(
          'Share at least a few memories with Emori first — then I can start seeing patterns in your life 🌱',
        );
        return;
      }

      final summaries = entries.map((e) => e.summary).toList();
      final aiService = ref.read(aiServiceProvider);
      final result = await aiService.detectPatterns(summaries);
      state = AsyncData(result);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

// ─── Weekly Reflection ───────────────────────────────────────────

final weeklyReflectionProvider =
    AsyncNotifierProvider<WeeklyReflectionNotifier, String?>(
      WeeklyReflectionNotifier.new,
    );

class WeeklyReflectionNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<void> generate() async {
    state = const AsyncLoading();
    try {
      final entries = await AppDatabase.instance.getThisWeeksEntries();

      if (entries.isEmpty) {
        state = const AsyncData(
          "You haven't shared anything with me this week yet 💜\n\nCome back after a few days of journaling and I'll write you something meaningful.",
        );
        return;
      }

      final summaries = entries.map((e) => e.summary).toList();
      final aiService = ref.read(aiServiceProvider);
      final result = await aiService.generateWeeklyReflection(summaries);
      state = AsyncData(result);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}
