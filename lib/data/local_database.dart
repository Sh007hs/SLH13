import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    // Keep the exact database filename used by version 1.0.1.
    _db = await openDatabase(
      join(dir, 'slh_hawk_parent_v101.db'),
      version: 2,
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addColumnIfMissing(db, 'children', 'photo_path', 'TEXT');
          await _addColumnIfMissing(db, 'teams', 'logo_path', 'TEXT');
        }
      },
    );
    return _db!;
  }

  Future<void> _addColumnIfMissing(DatabaseExecutor db, String table,
      String column, String type) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    if (!info.any((r) => r['name'] == column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE children(
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      birth_date TEXT, height REAL, weight REAL, preferred_foot TEXT,
      primary_position TEXT, secondary_positions TEXT, photo_path TEXT,
      created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE competitions(
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      season TEXT, format TEXT, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE teams(
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      academy TEXT, start_date TEXT, end_date TEXT, logo_path TEXT,
      created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE matches(
      id INTEGER PRIMARY KEY AUTOINCREMENT, child_id INTEGER NOT NULL,
      competition_id INTEGER, opponent TEXT NOT NULL, match_date TEXT NOT NULL,
      participation TEXT, entry_minute INTEGER, exit_minute INTEGER,
      minutes INTEGER DEFAULT 0, position TEXT, home_score INTEGER DEFAULT 0,
      away_score INTEGER DEFAULT 0, goals INTEGER DEFAULT 0, assists INTEGER DEFAULT 0,
      rating REAL, notes TEXT, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE training_sessions(
      id INTEGER PRIMARY KEY AUTOINCREMENT, child_id INTEGER NOT NULL,
      title TEXT NOT NULL, session_date TEXT NOT NULL,
      attended INTEGER NOT NULL DEFAULT 1, notes TEXT, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE injuries(
      id INTEGER PRIMARY KEY AUTOINCREMENT, child_id INTEGER NOT NULL,
      description TEXT NOT NULL, start_date TEXT NOT NULL, return_date TEXT,
      notes TEXT, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE audit_log(
      id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL,
      entity_id INTEGER, action TEXT NOT NULL, details TEXT, created_at TEXT NOT NULL)''');
    await db.execute('CREATE TABLE app_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  }

  static const allowedTables = {
    'children', 'competitions', 'teams', 'matches',
    'training_sessions', 'injuries', 'audit_log'
  };

  Future<List<Map<String, Object?>>> rows(String table, {String? orderBy}) async {
    if (!allowedTables.contains(table)) throw ArgumentError('Unknown table');
    return (await database).query(table, orderBy: orderBy);
  }

  Future<int> save(String table, Map<String, Object?> values, {int? id}) async {
    if (!allowedTables.contains(table) || table == 'audit_log') {
      throw ArgumentError('Table cannot be modified');
    }
    final db = await database;
    final data = Map<String, Object?>.from(values);
    if (const {'matches', 'training_sessions', 'injuries'}.contains(table)) {
      final childId = data['child_id'];
      final found = childId is int && (await db.query('children',
          columns: ['id'], where: 'id = ?', whereArgs: [childId], limit: 1)).isNotEmpty;
      if (!found) throw ArgumentError('Select a valid child profile.');
    }
    return db.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();
      late int recordId;
      late String action;
      if (id == null) {
        data['created_at'] ??= now;
        recordId = await txn.insert(table, data);
        action = 'insert';
      } else {
        data.remove('created_at');
        final count = await txn.update(table, data, where: 'id = ?', whereArgs: [id]);
        if (count == 0) throw StateError('Record not found');
        recordId = id;
        action = 'update';
      }
      await _audit(txn, table, recordId, action);
      return recordId;
    });
  }

  Future<void> remove(String table, int id) async {
    if (!allowedTables.contains(table) || table == 'audit_log') {
      throw ArgumentError('Table cannot be modified');
    }
    final db = await database;
    await db.transaction((txn) async {
      final n = await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      if (n > 0) await _audit(txn, table, id, 'delete');
    });
  }

  Future<void> _audit(DatabaseExecutor db, String table, int id, String action) async {
    await db.insert('audit_log', {
      'entity': table, 'entity_id': id, 'action': action,
      'details': '', 'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<int> count(String table) async {
    if (!allowedTables.contains(table)) throw ArgumentError('Unknown table');
    return Sqflite.firstIntValue(
      await (await database).rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;
  }

  Future<Map<String, int>> summary() async => {
    'children': await count('children'),
    'matches': await count('matches'),
    'competitions': await count('competitions'),
    'training': await count('training_sessions'),
  };
}
