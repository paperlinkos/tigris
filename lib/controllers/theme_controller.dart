import 'package:flutter/material.dart';
import '../persistence/storage_interface.dart';

class ThemeController extends ChangeNotifier {
  static const String _collection = 'settings';
  static const String _key = 'theme_mode';

  final StorageInterface? _storage;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeController({StorageInterface? storage}) : _storage = storage {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadThemeMode() async {
    final storage = _storage;
    if (storage == null) return;
    try {
      final raw = await storage.get(_collection, _key);
      if (raw != null && raw['mode'] != null) {
        final modeStr = raw['mode'] as String;
        if (modeStr == 'light') {
          _themeMode = ThemeMode.light;
        } else if (modeStr == 'dark') {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final storage = _storage;
    if (storage != null) {
      try {
        final modeStr = mode == ThemeMode.light
            ? 'light'
            : mode == ThemeMode.dark
                ? 'dark'
                : 'system';
        await storage.set(_collection, _key, {'mode': modeStr});
      } catch (_) {}
    }
  }

  Future<void> toggleDarkMode() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}

class ThemeControllerScope extends InheritedWidget {
  final ThemeController themeController;

  const ThemeControllerScope({
    super.key,
    required this.themeController,
    required super.child,
  });

  static ThemeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeControllerScope>()
        ?.themeController;
  }

  static ThemeController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No ThemeControllerScope found in context');
    return controller!;
  }

  @override
  bool updateShouldNotify(ThemeControllerScope oldWidget) {
    return themeController != oldWidget.themeController;
  }
}
