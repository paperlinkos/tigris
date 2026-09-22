import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_interface.dart';

/// Persistent implementation of [StorageInterface] using [SharedPreferences].
/// Stores each collection as a serialized JSON map of IDs to document objects.
class PreferencesStorage implements StorageInterface {
  static const String _keyPrefix = 'tigris_storage_';

  final SharedPreferences? _prefsInstance;

  PreferencesStorage([this._prefsInstance]);

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ?? await SharedPreferences.getInstance();
  }

  String _collectionKey(String collection) => '$_keyPrefix$collection';

  Future<Map<String, Map<String, dynamic>>> _loadCollection(String collection) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_collectionKey(collection));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveCollection(
    String collection,
    Map<String, Map<String, dynamic>> data,
  ) async {
    final prefs = await _getPrefs();
    await prefs.setString(_collectionKey(collection), jsonEncode(data));
  }

  @override
  Future<void> set(String collection, String id, Map<String, dynamic> data) async {
    final map = await _loadCollection(collection);
    map[id] = data;
    await _saveCollection(collection, map);
  }

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final map = await _loadCollection(collection);
    return map[id];
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(String collection) async {
    final map = await _loadCollection(collection);
    return map.values.toList();
  }

  @override
  Future<void> delete(String collection, String id) async {
    final map = await _loadCollection(collection);
    if (map.containsKey(id)) {
      map.remove(id);
      await _saveCollection(collection, map);
    }
  }

  @override
  Future<void> clear(String collection) async {
    final prefs = await _getPrefs();
    await prefs.remove(_collectionKey(collection));
  }
}
