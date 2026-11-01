class BackupFile {
  final String id;
  final String name;
  final DateTime createdAt;

  const BackupFile({
    required this.id,
    required this.name,
    required this.createdAt,
  });
}

class BackupNotConnectedException implements Exception {}

class BackupStoreException implements Exception {
  final int statusCode;
  final String message;

  const BackupStoreException(this.statusCode, this.message);
}

abstract class BackupStore {
  Future<List<BackupFile>> listBackups();
  Future<BackupFile> upload({
    required String baseName,
    required String json,
    required String readable,
  });
  Future<String> download(BackupFile file);
  Future<void> delete(BackupFile file);
}
