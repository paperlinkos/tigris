import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/navigation/app_shell.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';

Future<LocalNoteRepository> _pumpPhone(WidgetTester tester, {List<Note> notes = const []}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final storage = InMemoryStorage();
  final repository = LocalNoteRepository(storage: storage);
  for (final note in notes) {
    await repository.saveNote(note);
  }
  // Like main.dart, the scope sits above the Navigator so pushed pages see it.
  await tester.pumpWidget(RepositoryScope(
    noteRepository: repository,
    reviewRepository: LocalReviewRepository(storage: storage),
    child: MaterialApp(theme: AppTheme.lightTheme, home: AppShell(storage: storage, noteRepository: repository)),
  ));
  await tester.pumpAndSettle();
  return repository;
}

Note _idea(String id, String title, {String content = ''}) => Note(
  id: id,
  title: title,
  content: content,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  workspace: Note.ideasWorkspace,
  ideaStatus: 'Spark',
);

Note _note(String id, String title) => Note(
  id: id,
  title: title,
  content: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('phone switch sits below title and changes the list', (tester) async {
    await _pumpPhone(tester, notes: [_note('note', 'Notebook'), _idea('idea', 'Idea book')]);
    final title = tester.getTopLeft(find.text('Notes').first);
    final switchTop = tester.getTopLeft(find.byKey(const Key('workspace_ideas_button')));
    expect(switchTop.dy, greaterThan(title.dy));
    await tester.tap(find.byKey(const Key('workspace_ideas_button')));
    await tester.pumpAndSettle();
    expect(find.text('Idea book'), findsOneWidget);
    expect(find.text('Notebook'), findsNothing);
  });

  testWidgets('creating an idea on phone writes an ideas note', (tester) async {
    final repository = await _pumpPhone(tester);
    await tester.tap(find.byKey(const Key('workspace_ideas_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new_note_button')));
    await tester.pumpAndSettle();
    expect((await repository.getAllNotes()).single.workspace, Note.ideasWorkspace);
  });

  testWidgets('Ship to agent is a full phone page and copy works', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _pumpPhone(tester, notes: [_idea('idea', 'Idea', content: 'Goal')]);
    await tester.tap(find.byKey(const Key('workspace_ideas_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_row_idea')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ship to agent'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.text('Copy brief'));
    await tester.pumpAndSettle();
    expect(copied, contains('# Idea'));
  });

  testWidgets('390 by 844 phone layout does not overflow in either workspace', (tester) async {
    await _pumpPhone(tester, notes: [_note('note', 'Notebook'), _idea('idea', 'Idea book')]);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('workspace_ideas_button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
