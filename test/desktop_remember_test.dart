import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/navigation/desktop_ui_state.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/persistence/storage_interface.dart';

class _Storage implements StorageInterface {
  final InMemoryStorage memory = InMemoryStorage();
  bool throwGet = false;
  bool throwSet = false;
  int gets = 0;
  int sets = 0;
  @override
  Future<void> clear(String collection) => memory.clear(collection);
  @override
  Future<void> delete(String collection, String id) =>
      memory.delete(collection, id);
  @override
  Future<List<Map<String, dynamic>>> getAll(String collection) =>
      memory.getAll(collection);
  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    gets++;
    if (throwGet) throw StateError('read failed');
    return memory.get(collection, id);
  }

  @override
  Future<void> set(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    sets++;
    if (throwSet) throw StateError('write failed');
    await memory.set(collection, id, data);
  }
}

void main() {
  test('missing state has the documented defaults', () async {
    final state = await DesktopUiStateStore(InMemoryStorage()).load();
    expect(state.openNoteId, isNull);
    expect(state.sidebarWidth, 280);
    expect(state.sidebarHidden, isFalse);
    expect(state.expandedIds, isEmpty);
  });

  test('state round trips as one desktop document', () async {
    final storage = InMemoryStorage();
    final store = DesktopUiStateStore(storage);
    await store.save(
      const DesktopUiState(
        openNoteId: 'two',
        sidebarWidth: 320,
        sidebarHidden: true,
        expandedIds: {'one'},
      ),
    );
    final raw = await storage.get('ui_state', 'desktop');
    final state = await store.load();
    expect(raw!['version'], 1);
    expect(state.openNoteId, 'two');
    expect(state.sidebarWidth, 320);
    expect(state.sidebarHidden, isTrue);
    expect(state.expandedIds, {'one'});
  });

  test('invalid values are made safe', () async {
    final storage = InMemoryStorage();
    await storage.set('ui_state', 'desktop', {
      'openNoteId': 5,
      'sidebarWidth': 9999,
      'sidebarHidden': 3,
      'expandedIds': [1, null, 'kept'],
    });
    final state = await DesktopUiStateStore(storage).load();
    expect(state.openNoteId, isNull);
    expect(state.sidebarWidth, 420);
    expect(state.sidebarHidden, isFalse);
    expect(state.expandedIds, {'kept'});
  });

  test('low, non-finite, and wrong widths use safe values', () async {
    final storage = InMemoryStorage();
    await storage.set('ui_state', 'desktop', {'sidebarWidth': 1});
    expect((await DesktopUiStateStore(storage).load()).sidebarWidth, 220);
    await storage.set('ui_state', 'desktop', {'sidebarWidth': double.nan});
    expect((await DesktopUiStateStore(storage).load()).sidebarWidth, 280);
  });

  test('storage failures never escape cosmetic state operations', () async {
    final storage = _Storage()..throwGet = true;
    expect((await DesktopUiStateStore(storage).load()).sidebarWidth, 280);
    storage.throwGet = false;
    storage.throwSet = true;
    await DesktopUiStateStore(
      storage,
    ).save(const DesktopUiState(sidebarWidth: 300));
    expect(storage.sets, 1);
  });
}
