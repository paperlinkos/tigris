import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/navigation/app_shell.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/offline_first_note_repository.dart';
import 'package:tigris/widgets/editor/block_note_editor.dart';

Finder _body() => find.descendant(of: find.byType(BlockNoteEditor), matching: find.byType(EditableText));

void main() {
  for (final width in [400.0, 1280.0]) {
    testWidgets('text typed right after Enter in a new note survives the title autosave (width $width)', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final storage = InMemoryStorage();
      final local = LocalNoteRepository(storage: storage);
      final repo = OfflineFirstNoteRepository(localRepo: local);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: AppShell(storage: storage, noteRepository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key(width < 900 ? 'new_note_button' : 'desktop_new_note')));
      await tester.pumpAndSettle();

      tester.testTextInput.enterText('My title');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      tester.testTextInput.enterText('typed straight away');
      await tester.pump(const Duration(milliseconds: 50));

      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      final field = tester.widget<EditableText>(_body().first);
      expect(field.controller.text, 'typed straight away');
      expect(field.focusNode.hasFocus, isTrue);
      final saved = (await local.getAllNotes()).single;
      expect(saved.title, 'My title');
      expect(saved.content, 'typed straight away');
    });
  }
}
