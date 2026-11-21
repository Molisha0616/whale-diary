import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/app_message.dart';
import '../models/entry.dart';
import '../models/entry_comment.dart';
import '../models/entry_media.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'whale_diary.db'),
      version: 6,
      onCreate: (db, version) async {
        await _createEntries(db);
        await _createComments(db);
        await _createMessages(db);
        await _createMedia(db);
        await _createSettings(db);
        await _createReports(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await _createMessages(db);
        }
        if (oldV < 3) {
          await db.execute('ALTER TABLE messages ADD COLUMN read INTEGER NOT NULL DEFAULT 0');
        }
        if (oldV < 4) {
          await _createMedia(db);
        }
        if (oldV < 5) {
          await _createSettings(db);
        }
        if (oldV < 6) {
          await _createReports(db);
        }
      },
    );
    return _db!;
  }

  Future<void> _createEntries(Database db) async {
    await db.execute('''
      CREATE TABLE entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'entry',
        plan_state TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_entries_day ON entries(day)');
  }

  Future<void> _createComments(Database db) async {
    await db.execute('''
      CREATE TABLE comments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        body TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_comments_entry ON comments(entry_id)');
  }

  Future<void> _createMessages(Database db) async {    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL,
        kind TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        entry_id INTEGER,
        read INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_messages_kind ON messages(kind)');
  }

  Future<void> _createMedia(Database db) async {
    await db.execute('''
      CREATE TABLE media(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id INTEGER NOT NULL,
        kind TEXT NOT NULL,
        path TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_media_entry ON media(entry_id)');
  }

  Future<int> insertMedia(EntryMedia m) async {
    final d = await db;
    return d.insert('media', m.toMap());
  }

  Future<List<EntryMedia>> mediaForEntry(int entryId) async {
    final d = await db;
    final rows = await d.query('media',
        where: 'entry_id = ?', whereArgs: [entryId], orderBy: 'created_at ASC');
    return rows.map(EntryMedia.fromMap).toList();
  }

  /// entryId -> 首张照片路径，用于首页卡片缩略图
  Future<Map<int, String>> firstPhotoMap() async {
    final d = await db;
    final rows = await d.query('media',
        columns: ['entry_id', 'path'],
        where: "kind = 'photo'",
        orderBy: 'created_at ASC');
    final map = <int, String>{};
    for (final r in rows) {
      final id = r['entry_id'] as int;
      map.putIfAbsent(id, () => r['path'] as String);
    }
    return map;
  }

  Future<void> _createSettings(Database db) async {
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createReports(Database db) async {
    await db.execute('''
      CREATE TABLE reports(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        period_start TEXT NOT NULL,
        period_end TEXT NOT NULL,
        generated_at INTEGER NOT NULL,
        body TEXT NOT NULL,
        model TEXT
      )
    ''');
  }

  Future<int> insertReport({
    required String kind,
    required String periodStart,
    required String periodEnd,
    required String body,
    String? model,
  }) async {
    final d = await db;
    return d.insert('reports', {
      'kind': kind,
      'period_start': periodStart,
      'period_end': periodEnd,
      'generated_at': DateTime.now().millisecondsSinceEpoch,
      'body': body,
      'model': model,
    });
  }

  Future<List<Map<String, Object?>>> allReports() async {
    final d = await db;
    return d.query('reports', orderBy: 'period_start ASC');
  }

  Future<Map<String, Object?>?> reportFor(
      String kind, String periodStart) async {
    final d = await db;
    final rows = await d.query('reports',
        where: 'kind = ? AND period_start = ?',
        whereArgs: [kind, periodStart],
        orderBy: 'generated_at DESC',
        limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// 某一天内容的“指纹”：记录条数 + 最大 id + 评论条数。
  /// 用来判断日报生成之后，这一天是不是又添了新东西。
  Future<String> daySignature(String dayKey) async {
    final d = await db;
    final e = await d.rawQuery(
      'SELECT COUNT(*) AS c, IFNULL(MAX(id), 0) AS m FROM entries WHERE day = ?',
      [dayKey],
    );
    final c = await d.rawQuery(
      'SELECT COUNT(*) AS c FROM comments WHERE entry_id IN '
      '(SELECT id FROM entries WHERE day = ?)',
      [dayKey],
    );
    return '${e.first['c']}:${e.first['m']}:${c.first['c']}';
  }

  /// 最早一条记录的日期（用于给日期选择器兜底）
  Future<String?> earliestDay() async {
    final d = await db;
    final rows = await d.rawQuery('SELECT MIN(day) AS m FROM entries');
    return rows.first['m'] as String?;
  }

  /// 历年同一天（同月同日）的记录
  Future<List<Entry>> entriesOnThisDay(int month, int day) async {
    final d = await db;
    final mmdd =
        '-';
    final rows = await d.query('entries',
        where: 'substr(day, 6, 5) = ?',
        whereArgs: [mmdd],
        orderBy: 'day DESC, created_at DESC');
    return rows.map(Entry.fromMap).toList();
  }

  Future<List<Entry>> entriesBetween(String start, String end) async {
    final d = await db;
    final rows = await d.query('entries',
        where: 'day >= ? AND day <= ?',
        whereArgs: [start, end],
        orderBy: 'day ASC, created_at ASC');
    return rows.map(Entry.fromMap).toList();
  }

  Future<List<EntryMedia>> mediaForEntryIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final d = await db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await d.query('media',
        where: 'entry_id IN ($placeholders)',
        whereArgs: ids,
        orderBy: 'created_at ASC');
    return rows.map(EntryMedia.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> dumpTable(String table) async {
    final d = await db;
    return d.query(table);
  }

  Future<String?> getSetting(String key) async {
    final d = await db;
    final rows =
        await d.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final d = await db;
    await d.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> insertEntry(Entry e) async {
    final d = await db;
    return d.insert('entries', e.toMap());
  }

  Future<List<Entry>> entriesForDay(String day) async {
    final d = await db;
    final rows = await d.query('entries',
        where: 'day = ?', whereArgs: [day], orderBy: 'created_at ASC');
    return rows.map(Entry.fromMap).toList();
  }

  Future<List<Entry>> plansForDay(String day) async {
    final d = await db;
    final rows = await d.query('entries',
        where: "day = ? AND type = 'plan'",
        whereArgs: [day],
        orderBy: 'created_at ASC');
    return rows.map(Entry.fromMap).toList();
  }

  Future<Entry?> entryById(int id) async {
    final d = await db;
    final rows = await d.query('entries', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Entry.fromMap(rows.first);
  }

  Future<void> setPlanState(int id, String state) async {
    final d = await db;
    await d.update('entries', {'plan_state': state},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertComment(EntryComment c) async {
    final d = await db;
    return d.insert('comments', c.toMap());
  }

  Future<List<EntryComment>> commentsForEntry(int entryId) async {
    final d = await db;
    final rows = await d.query('comments',
        where: 'entry_id = ?',
        whereArgs: [entryId],
        orderBy: 'created_at ASC');
    return rows.map(EntryComment.fromMap).toList();
  }

  Future<List<Entry>> unconfirmedPlansBefore(String day) async {
    final d = await db;
    final rows = await d.query('entries',
        where: "type = 'plan' AND plan_state IS NULL AND day < ?",
        whereArgs: [day],
        orderBy: 'day ASC');
    return rows.map(Entry.fromMap).toList();
  }

  Future<bool> hasPlanReminder(int entryId) async {
    final d = await db;
    final rows = await d.query('messages',
        where: "kind = 'plan_unconfirmed' AND entry_id = ?",
        whereArgs: [entryId],
        limit: 1);
    return rows.isNotEmpty;
  }

  Future<int> insertMessage(AppMessage m) async {
    final d = await db;
    return d.insert('messages', m.toMap());
  }

  Future<List<AppMessage>> messages() async {
    final d = await db;
    final rows = await d.query('messages', orderBy: 'created_at DESC');
    return rows.map(AppMessage.fromMap).toList();
  }

  Future<int> unreadCount() async {
    final d = await db;
    final rows =
        await d.rawQuery('SELECT COUNT(*) AS c FROM messages WHERE read = 0');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> markAllRead() async {
    final d = await db;
    await d.update('messages', {'read': 1}, where: 'read = 0');
  }

  Future<List<String>> daysWithEntries(int year, int month) async {
    final d = await db;
    final prefix = '$year-${month.toString().padLeft(2, '0')}-';
    final rows = await d.rawQuery(
        'SELECT DISTINCT day FROM entries WHERE day LIKE ?', ['$prefix%']);
    return rows.map((r) => r['day'] as String).toList();
  }
}







