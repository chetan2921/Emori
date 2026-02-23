import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/entry.dart';
import '../models/chat_message.dart';
import '../models/reminder.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;
  static String? _currentUserId;

  AppDatabase._init();

  /// Initialize database for a specific user.
  /// Each user gets their own database file.
  Future<void> initForUser(String userId) async {
    // If already initialized for this user, skip
    if (_currentUserId == userId && _database != null) return;

    // Close previous database if open
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    _currentUserId = userId;
    _database = await _initDB(userId);
  }

  /// Close the current database and reset (for logout).
  Future<void> closeAndReset() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _currentUserId = null;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Fallback: use 'default' if no user is set (shouldn't happen in normal flow)
    _database = await _initDB(_currentUserId ?? 'default');
    return _database!;
  }

  Future<Database> _initDB(String userId) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'emori_$userId.db');

    // Uncomment to reset DB for testing during dev:
    // await deleteDatabase(path);

    return await openDatabase(
      path,
      version: 4,
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
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE reminders (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              due_date INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              is_completed INTEGER NOT NULL DEFAULT 0,
              is_notified INTEGER NOT NULL DEFAULT 0,
              related_entry_id TEXT
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

    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        due_date INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_notified INTEGER NOT NULL DEFAULT 0,
        related_entry_id TEXT
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

  /// Wipe all data from the current user's database.
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('entries');
    await db.delete('chat_messages');
    await db.delete('reminders');
  }

  // --- REMINDERS ---

  /// Insert a new reminder.
  Future<void> insertReminder(Reminder reminder) async {
    final db = await database;
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all upcoming reminders (not completed, due in the future or today).
  Future<List<Reminder>> getUpcomingReminders() async {
    final db = await database;
    final now = DateTime.now()
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch;

    final maps = await db.query(
      'reminders',
      where: 'is_completed = 0 AND due_date >= ?',
      whereArgs: [now],
      orderBy: 'due_date ASC',
    );
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  /// Get reminders that need notification (due within next 2 days, not yet notified).
  Future<List<Reminder>> getRemindersNeedingNotification() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final twoDaysFromNow = DateTime.now()
        .add(const Duration(days: 2))
        .millisecondsSinceEpoch;

    final maps = await db.query(
      'reminders',
      where:
          'is_completed = 0 AND is_notified = 0 AND due_date >= ? AND due_date <= ?',
      whereArgs: [now, twoDaysFromNow],
      orderBy: 'due_date ASC',
    );
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  /// Get all reminders.
  Future<List<Reminder>> getAllReminders() async {
    final db = await database;
    final maps = await db.query('reminders', orderBy: 'due_date ASC');
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  /// Mark a reminder as notified.
  Future<void> markReminderNotified(String id) async {
    final db = await database;
    await db.update(
      'reminders',
      {'is_notified': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark a reminder as completed.
  Future<void> markReminderCompleted(String id) async {
    final db = await database;
    await db.update(
      'reminders',
      {'is_completed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a reminder.
  Future<void> deleteReminder(String id) async {
    final db = await database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // --- MISC ---

  /// Close database connection.
  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
