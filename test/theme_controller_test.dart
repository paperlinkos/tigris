import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/controllers/theme_controller.dart';
import 'package:tigris/persistence/in_memory_storage.dart';

void main() {
  group('ThemeController Tests', () {
    late InMemoryStorage storage;

    setUp(() {
      storage = InMemoryStorage();
    });

    test('Defaults to ThemeMode.system and updates ThemeMode correctly', () async {
      final controller = ThemeController(storage: storage);
      expect(controller.themeMode, equals(ThemeMode.system));

      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, equals(ThemeMode.dark));
      expect(controller.isDarkMode, isTrue);

      await controller.toggleDarkMode();
      expect(controller.themeMode, equals(ThemeMode.light));
      expect(controller.isDarkMode, isFalse);
    });

    test('Persists theme mode to storage across instances', () async {
      final controller1 = ThemeController(storage: storage);
      await controller1.setThemeMode(ThemeMode.dark);

      final controller2 = ThemeController(storage: storage);
      // Wait for async loading
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller2.themeMode, equals(ThemeMode.dark));
    });
  });
}
