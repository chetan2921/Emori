import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/entry.dart';
import '../models/chat_message.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'emori.db');

    // Uncomment to reset DB for testing during dev:
    // await deleteDatabase(path);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE entries ADD COLUMN image_paths TEXT NOT NULL DEFAULT ""',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE chat_messages (
              id TEXT PRIMARY KEY,
              text TEXT NOT NULL,
              is_user INTEGER NOT NULL,
              session_type TEXT NOT NULL,
              image_paths TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL
            )
          ''');
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE entries (
        id TEXT PRIMARY KEY,
        raw_text TEXT NOT NULL,
        summary TEXT NOT NULL,
        emotions TEXT NOT NULL,
        life_area TEXT NOT NULL,
        type TEXT NOT NULL,
        themes TEXT NOT NULL,
        people TEXT NOT NULL,
        embedding BLOB NOT NULL,
        image_paths TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        session_type TEXT NOT NULL,
        image_paths TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
  }

  // --- ENTRIES ---

  /// Insert a new entry.
  Future<void> insertEntry(Entry entry) async {
    final db = await database;
    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all entries sorted by newest first.
  Future<List<Entry>> getAllEntries() async {
    final db = await database;
    final maps = await db.query('entries', orderBy: 'created_at DESC');
    return maps.map((map) => Entry.fromMap(map)).toList();
  }

  /// Get entries from the last N days.
  Future<List<Entry>> getEntriesFromLastDays(int days) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    final maps = await db.query(
      'entries',
      where: 'created_at >= ?',
      whereArgs: [cutoff],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Entry.fromMap(map)).toList();
  }

  /// Get entries from the last 7 days.
  Future<List<Entry>> getThisWeeksEntries() async {
    return getEntriesFromLastDays(7);
  }

  /// Get all entries with their embeddings (for similarity search).
  Future<List<Entry>> getAllEntriesWithEmbeddings() async {
    return getAllEntries();
  }

  /// Delete an entry by ID.
  Future<void> deleteEntry(String id) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  // --- CHAT MESSAGES ---

  /// Insert a chat message.
  Future<void> insertChatMessage(ChatMessage message) async {
    final db = await database;
    await db.insert(
      'chat_messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all messages for a specific session ('chat' or 'capture').
  Future<List<ChatMessage>> getChatMessages(String sessionType) async {
    final db = await database;
    final maps = await db.query(
      'chat_messages',
      where: 'session_type = ?',
      whereArgs: [sessionType],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => ChatMessage.fromMap(map)).toList();
  }

  /// Clear messages for a specific session.
  Future<void> clearChatMessages(String sessionType) async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'session_type = ?',
      whereArgs: [sessionType],
    );
  }

  // --- MISC ---

  /// Close database connection.
  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
