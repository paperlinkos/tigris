import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/navigation/app_shell.dart';
import 'package:tigris/app/navigation/desktop_shell.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/persistence/storage_interface.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/offline_first_note_repository.dart';

/// Counts and can slow down or break reads and writes of the remembered state.
class _Storage implements StorageInterface {
  final memory = InMemoryStorage();
  bool throwGet = false;
  bool throwSet = false;
  Duration stateDelay = Duration.zero;
  Duration notesDelay = Duration.zero;
  int uiGets = 0;
  int uiSets = 0;

  @override
  Future<void> set(String c, String id, Map<String, dynamic> d) async {
    if (c == 'ui_state') {
      uiSets++;
      if (throwSet) throw StateError('write failed');
    }
    await memory.set(c, id, d);
  }

  @override
  Future<Map<String, dynamic>?> get(String c, String id) async {
    if (c == 'ui_state') {
      uiGets++;
      if (stateDelay > Duration.zero) await Future<void>.delayed(stateDelay);
      if (throwGet) throw StateError('read failed');
    }
    return memory.get(c, id);
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(String c) async {
    if (c == 'notes' && notesDelay > Duration.zero) await Future<void>.delayed(notesDelay);
    return memory.getAll(c);
  }

  @override
  Future<void> delete(String c, String id) => memory.delete(c, id);
  @override
  Future<void> clear(String c) => memory.clear(c);
}

Note _note(String id, String title, DateTime at, {String? parentId}) =>
    Note(id: id, title: title, content: 'text of $title', parentId: parentId, createdAt: at, updatedAt: at);

Future<void> _size(WidgetTester tester, [Size size = const Size(1280, 800)]) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<_Storage> _seeded() async {
  final storage = _Storage();
  final repo = OfflineFirstNoteRepository(localRepo: LocalNoteRepository(storage: storage));
  await repo.saveNote(_note('top', 'Top', DateTime(2026, 1)));
  await repo.saveNote(_note('other', 'Other', DateTime(2099)));
  // Saving a child refreshes its parent's edit time, so 'Other' is dated far
  // ahead to stay the most recent note.
  await repo.saveNote(_note('child', 'Child', DateTime(2026, 3), parentId: 'top'));
  return storage;
}

Future<void> _mount(WidgetTester tester, _Storage storage, {bool app = false}) async {
  final repo = OfflineFirstNoteRepository(localRepo: LocalNoteRepository(storage: storage));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: app
        ? AppShell(storage: storage, noteRepository: repo)
        : DesktopShell(storage: storage, noteRepository: repo),
  ));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _wait(WidgetTester tester, [int ms = 600]) async {
  await tester.pump(Duration(milliseconds: ms));
  await tester.pumpAndSettle();
}

String _title(WidgetTester tester) => tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text;
double _sidebarWidth(WidgetTester tester) => tester.getSize(find.byKey(const Key('desktop_sidebar'))).width;
Future<void> _toggleRow(WidgetTester tester, String id) async {
  // The arrow sits at the left edge of a compact row.
  await tester.tapAt(tester.getTopLeft(find.byKey(ValueKey('note_row_$id'))) + const Offset(12, 15));
  await tester.pumpAndSettle();
}

/// Loading steps that are delayed need real time to pass, not just frames.
Future<void> _slowSettle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> _openRow(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('note_row_$id')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first launch opens the most recent note with the default layout', (tester) async {
    await _size(tester);
    await _mount(tester, await _seeded());
    await tester.pumpAndSettle();
    expect(_title(tester), 'Other');
    expect(_sidebarWidth(tester), 280);
    expect(find.byKey(const Key('desktop_show_sidebar')), findsNothing);
  });

  testWidgets('the last open note comes back on the next launch', (tester) async {
    await _size(tester);
    final storage = await _seeded();
    await _mount(tester, storage);
    await tester.pumpAndSettle();
    await _openRow(tester, 'top');
    await _wait(tester);
    await _unmount(tester);

    await _mount(tester, storage);
    await tester.pumpAndSettle();
    expect(_title(tester), 'Top');
  });

  testWidgets('a remembered note that no longer exists falls back to the most recent', (tester) async {
    await _size(tester);
    final storage = await _seeded();
    await storage.memory.set('ui_state', 'desktop', {'id': 'desktop', 'openNoteId': 'ghost'});
    await _mount(tester, storage);
    await tester.pumpAndSettle();
    expect(_title(tester), 'Other');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sidebar width is remembered and kept in range', (tester) async {
    await _size(tester);
    final storage = await _seeded();
    await _mount(tester, storage);
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('desktop_divider')), const Offset(100, 0));
    await _wait(tester);
    expect(_sidebarWidth(tester), 380);
    await _unmount(tester);

    await _mount(tester, storage);
    await tester.pumpAndSettle();
    expect(_sidebarWidth(tester), 380);
    await _unmount(tester);

    for (final entry in {9999: 420.0, 1: 220.0}.entries) {
      await storage.memory.set('ui_state', 'desktop', {'id': 'desktop', 'sidebarWidth': entry.key});
      await _mount(tester, storage);
      await tester.pumpAndSettle();
      expect(_sidebarWidth(tester), entry.value);
      await _unmount(tester);
    }
  });

  testWidgets('a hidden sidebar stays hidden, and can be shown again', (tester) async {
    await _size(tester);
    final storage = await _seeded();
    await _mount(tester, storage);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('desktop_hide_sidebar')));
    await _wait(tester);
    await _unmount(tester);

    await _mount(tester, storage);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop_sidebar')), findsNothing);
    await tester.tap(find.byKey(const Key('desktop_show_sidebar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop_sidebar')), findsOneWidget);
  });

  testWidgets('expanded and collapsed notes are remembered, and deleted ones are dropped', (tester) async {
    await _size(tester);
    final storage = await _seeded();
    await _mount(tester, storage);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note_row_child')), findsNothing);

    await _toggleRow(tester, 'top');
    await _wait(tester);
    expect(find.byKey(const ValueKey('note_row_child')), findsOneWidget);
    await _unmount(tester);

    await _mount(tester, storage);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note_row_child')), findsOneWidget);

    await _toggleRow(tester, 'top');
    await _wait(tester);
    await _unmount(tester);

    await _mount(tester, storage);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note_row_child')), findsNothing);
    await _unmount(tester);

    await storage.memory.set('ui_state', 'desktop', {'id': 'desktop', 'expandedIds': ['ghost', 'top']});
    await _mount(tester, storage);
    await _wait(tester);
    final saved = await storage.memory.get('ui_state', 'desktop');
    expect(saved!['expandedIds'], isNot(contains('ghost')));
    expect(saved['expandedIds'], contains('top'));
  });

  testWidgets('dragging writes nothing until it pauses, then writes once', (tester) async {
    await _size(tester);
    final storage = await _seeded();
    await _mount(tester, storage);
    await _wait(tester);
    final before = storage.uiSets;

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('desktop_divider'))));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(storage.uiSets, before);
    await gesture.up();
    await _wait(tester);
    expect(storage.uiSets, before + 1);
  });

  testWidgets('closing right after a change still saves it', (tester) async {
    await _size(tester);
    final storage = await _seeded();
    await _mount(tester, storage);
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('desktop_divider')), const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await _unmount(tester);

    expect((await storage.memory.get('ui_state', 'desktop'))!['sidebarWidth'], 340);
  });

  testWidgets('a notes list that arrives late or early still opens the remembered note', (tester) async {
    await _size(tester);
    for (final slowNotes in [true, false]) {
      final storage = await _seeded();
      await storage.memory.set('ui_state', 'desktop', {'id': 'desktop', 'openNoteId': 'top'});
      if (slowNotes) {
        storage.notesDelay = const Duration(milliseconds: 300);
      } else {
        storage.stateDelay = const Duration(milliseconds: 300);
      }
      await _mount(tester, storage);
      await _slowSettle(tester);
      expect(_title(tester), 'Top', reason: slowNotes ? 'slow notes' : 'slow state');
      await _unmount(tester);
    }
  });

  testWidgets('nothing flashes the empty state while loading', (tester) async {
    await _size(tester);
    final storage = await _seeded();
    storage.notesDelay = const Duration(milliseconds: 300);
    await _mount(tester, storage);
    for (var i = 0; i < 20; i++) {
      expect(find.text('Your notes will appear here.'), findsNothing, reason: 'frame $i');
      await tester.pump(const Duration(milliseconds: 25));
    }
    await _slowSettle(tester);
    expect(_title(tester), 'Other');
  });

  group('when remembering fails', () {
    testWidgets('unreadable state opens with defaults', (tester) async {
      await _size(tester);
      final storage = await _seeded()..throwGet = true;
      await _mount(tester, storage);
      await tester.pumpAndSettle();
      expect(_title(tester), 'Other');
      expect(_sidebarWidth(tester), 280);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unwritable state never stops moving, resizing or opening notes', (tester) async {
      await _size(tester);
      final storage = await _seeded()..throwSet = false;
      await _mount(tester, storage);
      await tester.pumpAndSettle();
      storage.throwSet = true;
      await tester.drag(find.byKey(const Key('desktop_divider')), const Offset(50, 0));
      await _openRow(tester, 'top');
      await _wait(tester);
      expect(_title(tester), 'Top');
      expect(_sidebarWidth(tester), 330);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wrong types everywhere load as defaults', (tester) async {
      await _size(tester);
      final storage = await _seeded();
      await storage.memory.set('ui_state', 'desktop', {
        'openNoteId': 5, 'sidebarWidth': 'wide', 'sidebarHidden': 3, 'expandedIds': [1, null, 'top'],
      });
      await _mount(tester, storage);
      await tester.pumpAndSettle();
      expect(_title(tester), 'Other');
      expect(_sidebarWidth(tester), 280);
      expect(find.byKey(const Key('desktop_sidebar')), findsOneWidget);
    });

    testWidgets('a notes list that fails to load still shows the app', (tester) async {
      await _size(tester);
      final repo = _FailingNotes();
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: DesktopShell(storage: _Storage(), noteRepository: repo)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('desktop_sidebar')), findsOneWidget);
      expect(find.text('Create your first note'), findsOneWidget);
    });
  });

  group('across layouts', () {
    testWidgets('the phone layout never reads or writes the remembered state', (tester) async {
      await _size(tester, const Size(800, 800));
      final storage = await _seeded();
      await _mount(tester, storage, app: true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('new_note_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home_more_menu')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(2, 2));
      await _wait(tester);
      expect(storage.uiGets, 0);
      expect(storage.uiSets, 0);
    });

    testWidgets('going narrow and back keeps the note and the width', (tester) async {
      await _size(tester);
      final storage = await _seeded();
      await _mount(tester, storage, app: true);
      await tester.pumpAndSettle();
      await _openRow(tester, 'top');
      await tester.drag(find.byKey(const Key('desktop_divider')), const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 50));

      tester.view.physicalSize = const Size(800, 800);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('desktop_sidebar')), findsNothing);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(_title(tester), 'Top');
      expect(_sidebarWidth(tester), 320);
    });
  });
}

class _FailingNotes extends OfflineFirstNoteRepository {
  _FailingNotes() : super(localRepo: LocalNoteRepository(storage: InMemoryStorage()));
  @override
  Future<List<Note>> getAllNotes() async => throw StateError('cannot read notes');
}
