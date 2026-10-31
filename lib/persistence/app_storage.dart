import 'package:flutter/foundation.dart';
import 'preferences_storage.dart';
import 'sqlite_storage.dart';
import 'storage_interface.dart';

/// The single storage the app uses, so every feature reads and writes the same
/// data. Web has no SQLite plugin and keeps using [PreferencesStorage].
class AppStorage {
  static StorageInterface? _instance;

  static StorageInterface get instance =>
      _instance ??= kIsWeb ? PreferencesStorage() : SqliteStorage();

  @visibleForTesting
  static set instance(StorageInterface storage) => _instance = storage;
}
