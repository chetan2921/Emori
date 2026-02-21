import '../models/entry.dart';
import 'database.dart';

/// Data Access Object — thin wrapper over AppDatabase for cleaner access
/// patterns from providers and services.
class EntryDao {
  final AppDatabase _db;

  EntryDao([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<void> insert(Entry entry) => _db.insertEntry(entry);

  Future<List<Entry>> getAll() => _db.getAllEntries();

  Future<List<Entry>> getRecent(int days) => _db.getEntriesFromLastDays(days);

  Future<List<Entry>> getThisWeek() => _db.getThisWeeksEntries();

  Future<List<Entry>> getAllWithEmbeddings() =>
      _db.getAllEntriesWithEmbeddings();

  Future<void> delete(String id) => _db.deleteEntry(id);
}
