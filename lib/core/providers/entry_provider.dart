import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../models/entry.dart';
import '../services/ai_service.dart';
import '../services/image_service.dart';
import '../services/voyage_service.dart';

// ─── Service Providers ───────────────────────────────────────────

final aiServiceProvider = Provider<AIService>((ref) => AIService());

final voyageServiceProvider = Provider<VoyageService>((ref) => VoyageService());

final imageServiceProvider = Provider<ImageService>((ref) => ImageService());

// ─── Entries State ───────────────────────────────────────────────

final entriesProvider = AsyncNotifierProvider<EntriesNotifier, List<Entry>>(
  EntriesNotifier.new,
);

class EntriesNotifier extends AsyncNotifier<List<Entry>> {
  @override
  Future<List<Entry>> build() async {
    // Initial load, sort by newest first
    final entries = await AppDatabase.instance.getAllEntries();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// Clears in-memory entries immediately on logout so they don't flash
  /// for the next user before their DB loads.
  void clearEntriesForLogout() {
    state = const AsyncValue.data([]);
  }

  /// Full pipeline — called when user saves an entry.
  /// Image description → AI analysis → Voyage embedding → SQLite store → refresh.
  Future<void> addEntry(String rawText, {List<File> images = const []}) async {
    final aiService = ref.read(aiServiceProvider);
    final voyageService = ref.read(voyageServiceProvider);
    final imageService = ref.read(imageServiceProvider);

    // Step 1 — Describe images if any
    String imageDescription = '';
    List<String> savedImagePaths = [];

    if (images.isNotEmpty) {
      final descriptions = await Future.wait(
        images.map((img) => imageService.describeImage(img)),
      );
      imageDescription = descriptions.where((d) => d.isNotEmpty).join(' ');
      savedImagePaths = images.map((f) => f.path).toList();
    }

    // Step 2 — AI analysis (with image context)
    final analysis = await aiService.analyzeEntry(
      rawText,
      imageDescription: imageDescription,
    );

    // Step 3 — Generate embedding from summary
    final embedding = await voyageService.generateEmbedding(
      analysis['summary'] as String,
    );

    // Step 4 — Build entry
    final entry = Entry(
      id: const Uuid().v4(),
      rawText: rawText,
      summary: analysis['summary'] as String,
      emotions: List<String>.from(analysis['emotions']),
      lifeArea: analysis['life_area'] as String,
      type: analysis['type'] as String,
      themes: List<String>.from(analysis['themes']),
      people: List<String>.from(analysis['people']),
      embeddingBytes: VoyageService.embeddingToBytes(embedding),
      imagePaths: savedImagePaths,
      createdAt: DateTime.now(),
    );

    // Step 5 — Save to local SQLite
    await AppDatabase.instance.insertEntry(entry);

    // Step 6 — Refresh state (prepend new entry)
    state = AsyncData([entry, ...state.valueOrNull ?? []]);
  }

  /// Delete an entry by ID.
  Future<void> deleteEntry(String id) async {
    await AppDatabase.instance.deleteEntry(id);
    state = AsyncData(
      state.valueOrNull?.where((e) => e.id != id).toList() ?? [],
    );
  }

  /// Refresh entries from database.
  Future<void> refresh() async {
    state = AsyncData(await AppDatabase.instance.getAllEntries());
  }
}
