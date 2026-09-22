abstract class StorageInterface {
  Future<void> set(String collection, String id, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> get(String collection, String id);
  Future<List<Map<String, dynamic>>> getAll(String collection);
  Future<void> delete(String collection, String id);
  Future<void> clear(String collection);
}
