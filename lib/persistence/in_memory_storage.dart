import 'storage_interface.dart';

class InMemoryStorage implements StorageInterface {
  final Map<String, Map<String, Map<String, dynamic>>> _db = {};

  @override
  Future<void> set(String collection, String id, Map<String, dynamic> data) async {
    _db.putIfAbsent(collection, () => {});
    _db[collection]![id] = Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    return _db[collection]?[id];
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(String collection) async {
    final collectionMap = _db[collection];
    if (collectionMap == null) return [];
    return collectionMap.values.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  @override
  Future<void> delete(String collection, String id) async {
    _db[collection]?.remove(id);
  }

  @override
  Future<void> clear(String collection) async {
    _db[collection]?.clear();
  }
}
