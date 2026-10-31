import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'preferences_storage.dart';
import 'storage_interface.dart';

/// On-device implementation of [StorageInterface], with one database row per
/// document so a save only writes the document that changed.
///
/// The first time it opens, it copies anything saved by [PreferencesStorage]
/// into the database. The old data is left in place as a fallback copy.
class SqliteStorage implements StorageInterface {
  static const String _migratedFlag = 'preferences_migrated';

  final DatabaseFactory? _factory;
  final String? _path;
  final Future<SharedPreferences> Function() _legacyPrefs;

  Future<Database>? _database;

  SqliteStorage({
    DatabaseFactory? factory,
    String? path,
    Future<SharedPreferences> Function()? legacyPrefs,
  })  : _factory = factory,
        _path = path,
        _legacyPrefs = legacyPrefs ?? SharedPreferences.getInstance;

  Future<Database> get _db => _database ??= _open().catchError((Object e) {
        // Let the next call try again instead of keeping a failed open.
        _database = null;
        throw e;
      });

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ?? p.join(await factory.getDatabasesPath(), 'tigris.db');
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE documents ('
            'collection TEXT NOT NULL, '
            'id TEXT NOT NULL, '
            'data TEXT NOT NULL, '
            'PRIMARY KEY (collection, id))',
          );
          await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
        },
      ),
    );
    await _migrateFromPreferences(db);
    return db;
  }

  Future<void> _migrateFromPreferences(Database db) async {
    final done = await db.query('meta', where: 'key = ?', whereArgs: [_migratedFlag]);
    if (done.isNotEmpty) return;

    final prefs = await _legacyPrefs();
    await db.transaction((txn) async {
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(PreferencesStorage.keyPrefix)) continue;
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) continue;

        final collection = key.substring(PreferencesStorage.keyPrefix.length);
        final Map<String, dynamic> documents;
        try {
          documents = jsonDecode(raw) as Map<String, dynamic>;
        } catch (e) {
          // The unreadable original stays in SharedPreferences untouched.
          debugPrint('Could not migrate "$collection": $e');
          continue;
        }
        for (final entry in documents.entries) {
          await txn.insert(
            'documents',
            {'collection': collection, 'id': entry.key, 'data': jsonEncode(entry.value)},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await txn.insert('meta', {'key': _migratedFlag, 'value': '1'});
    });
  }

  @override
  Future<void> set(String collection, String id, Map<String, dynamic> data) async {
    final db = await _db;
    await db.insert(
      'documents',
      {'collection': collection, 'id': id, 'data': jsonEncode(data)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final db = await _db;
    final rows = await db.query(
      'documents',
      columns: ['data'],
      where: 'collection = ? AND id = ?',
      whereArgs: [collection, id],
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(String collection) async {
    final db = await _db;
    final rows = await db.query(
      'documents',
      columns: ['id', 'data'],
      where: 'collection = ?',
      whereArgs: [collection],
    );
    final documents = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        documents.add(jsonDecode(row['data'] as String) as Map<String, dynamic>);
      } catch (e) {
        // One bad row must not hide the rest. It stays in the database.
        debugPrint('Skipping unreadable document ${row['id']} in "$collection": $e');
      }
    }
    return documents;
  }

  @override
  Future<void> delete(String collection, String id) async {
    final db = await _db;
    await db.delete(
      'documents',
      where: 'collection = ? AND id = ?',
      whereArgs: [collection, id],
    );
  }

  @override
  Future<void> clear(String collection) async {
    final db = await _db;
    await db.delete('documents', where: 'collection = ?', whereArgs: [collection]);
  }
}
