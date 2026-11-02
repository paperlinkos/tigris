import 'package:flutter/foundation.dart';
import '../../persistence/storage_interface.dart';

class DesktopUiState {
  final String? openNoteId;
  final double sidebarWidth;
  final bool sidebarHidden;
  final Set<String> expandedIds;

  const DesktopUiState({
    this.openNoteId,
    this.sidebarWidth = 280,
    this.sidebarHidden = false,
    this.expandedIds = const {},
  });
}

class DesktopUiStateStore {
  final StorageInterface _storage;
  DesktopUiStateStore(this._storage);

  Future<DesktopUiState> load() async {
    try {
      final data = await _storage.get('ui_state', 'desktop');
      if (data == null) return const DesktopUiState();
      final rawWidth = data['sidebarWidth'];
      final width = rawWidth is num && rawWidth.isFinite
          ? rawWidth.toDouble().clamp(220.0, 420.0)
          : 280.0;
      final expanded = data['expandedIds'];
      return DesktopUiState(
        openNoteId: data['openNoteId'] is String
            ? data['openNoteId'] as String
            : null,
        sidebarWidth: width,
        sidebarHidden: data['sidebarHidden'] is bool
            ? data['sidebarHidden'] as bool
            : false,
        expandedIds: expanded is List
            ? expanded.whereType<String>().toSet()
            : const <String>{},
      );
    } catch (error) {
      debugPrint('Could not load desktop UI state: $error');
      return const DesktopUiState();
    }
  }

  Future<void> save(DesktopUiState state) async {
    try {
      await _storage.set('ui_state', 'desktop', {
        'id': 'desktop',
        'version': 1,
        'openNoteId': state.openNoteId,
        'sidebarWidth': state.sidebarWidth,
        'sidebarHidden': state.sidebarHidden,
        'expandedIds': state.expandedIds.toList(),
      });
    } catch (error) {
      debugPrint('Could not save desktop UI state: $error');
    }
  }
}
