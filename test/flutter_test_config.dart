import 'dart:async';
import 'package:tigris/persistence/app_storage.dart';
import 'package:tigris/persistence/preferences_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

/// The SQLite plugin doesn't run in widget tests, so they use mocked
/// SharedPreferences. `sqlite_storage_test.dart` covers SQLite directly.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppStorage.instance = PreferencesStorage();
  });
  await testMain();
}
