import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/navigation/app_shell.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/services/idea_brief.dart';
import 'package:tigris/widgets/ideas/workspace_switch.dart';

Future<LocalNoteRepository> _pumpDesktop(
  WidgetTester tester, {
  List<Note> notes = const [],
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final storage = InMemoryStorage();
  final repository = LocalNoteRepository(storage: storage);
  for (final note in notes) {
    await repository.saveNote(note);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppShell(storage: storage, noteRepository: repository),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Note _note(String id, String title, {String workspace = Note.notesWorkspace, String? parentId, String content = '', DateTime? updatedAt}) {
  final time = updatedAt ?? DateTime(2026, 1, 1);
  return Note(
    id: id,
    title: title,
    content: content,
    parentId: parentId,
    createdAt: time,
    updatedAt: time,
    workspace: workspace,
    ideaStatus: workspace == Note.ideasWorkspace && parentId == null ? 'Spark' : null,
  );
}

Future<void> _ideas(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('workspace_ideas_button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the switch shows Notes and Ideas and Notes starts selected', (tester) async {
    await _pumpDesktop(tester);
    expect(find.byKey(const Key('workspace_notes_button')), findsOneWidget);
    expect(find.byKey(const Key('workspace_ideas_button')), findsOneWidget);
    expect(tester.widget<WorkspaceSwitch>(find.byType(WorkspaceSwitch)).workspace, Note.notesWorkspace);
  });

  testWidgets('switching workspaces shows only that workspace', (tester) async {
    await _pumpDesktop(tester, notes: [_note('note', 'Notebook'), _note('idea', 'Idea book', workspace: Note.ideasWorkspace)]);
    await _ideas(tester);
    expect(find.text('Idea book'), findsWidgets);
    expect(find.text('Notebook'), findsNothing);
    await tester.tap(find.byKey(const Key('workspace_notes_button')));
    await tester.pumpAndSettle();
    expect(find.text('Notebook'), findsWidgets);
    expect(find.text('Idea book'), findsNothing);
  });

  testWidgets('search never crosses workspaces', (tester) async {
    await _pumpDesktop(tester, notes: [_note('note', 'Only note'), _note('idea', 'Only idea', workspace: Note.ideasWorkspace)]);
    await _ideas(tester);
    await tester.enterText(find.byKey(const Key('desktop_search')), 'Only note');
    await tester.pump();
    expect(find.byKey(const ValueKey('note_row_note')), findsNothing);
    await tester.tap(find.byKey(const Key('workspace_notes_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('desktop_search')), 'Only idea');
    await tester.pump();
    expect(find.byKey(const ValueKey('note_row_idea')), findsNothing);
  });

  testWidgets('new idea is Spark in the ideas workspace and focuses title', (tester) async {
    final repository = await _pumpDesktop(tester);
    await _ideas(tester);
    await tester.tap(find.byKey(const Key('desktop_new_note')));
    await tester.pumpAndSettle();
    final idea = (await repository.getAllNotes()).single;
    expect(idea.workspace, Note.ideasWorkspace);
    expect(idea.ideaStatus, 'Spark');
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).focusNode!.hasFocus, isTrue);
  });

  testWidgets('add page inside and duplicate retain idea workspace', (tester) async {
    final repository = await _pumpDesktop(tester, notes: [_note('idea', 'Parent', workspace: Note.ideasWorkspace)]);
    await _ideas(tester);
    await tester.longPress(find.byKey(const ValueKey('note_row_idea')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add page inside'));
    await tester.pumpAndSettle();
    final child = (await repository.getAllNotes()).firstWhere((note) => note.parentId == 'idea');
    expect(child.workspace, Note.ideasWorkspace);
    await tester.longPress(find.byKey(ValueKey('note_row_${child.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    final duplicate = (await repository.getAllNotes()).firstWhere((note) => note.id != 'idea' && note.id != child.id);
    expect(duplicate.workspace, Note.ideasWorkspace);
  });

  testWidgets('changing a status saves it and changes dot semantics', (tester) async {
    final repository = await _pumpDesktop(tester, notes: [_note('idea', 'Status', workspace: Note.ideasWorkspace)]);
    await _ideas(tester);
    await tester.tap(find.text('Ready').last);
    await tester.pumpAndSettle();
    expect((await repository.getNote('idea'))!.ideaStatus, 'Ready');
    expect(find.bySemanticsLabel('Ready'), findsWidgets);
  });

  testWidgets('nested idea pages do not show status controls', (tester) async {
    await _pumpDesktop(tester, notes: [_note('root', 'Root', workspace: Note.ideasWorkspace), _note('child', 'Child', workspace: Note.ideasWorkspace, parentId: 'root')]);
    await _ideas(tester);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_row_child')));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('each workspace remembers its selected note and search text', (tester) async {
    await _pumpDesktop(tester, notes: [_note('note', 'Note'), _note('idea', 'Idea', workspace: Note.ideasWorkspace)]);
    await tester.enterText(find.byKey(const Key('desktop_search')), 'Note');
    await _ideas(tester);
    await tester.enterText(find.byKey(const Key('desktop_search')), 'Idea');
    await tester.tap(find.byKey(const Key('workspace_notes_button')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('desktop_search'))).controller!.text, 'Note');
    await tester.tap(find.byKey(const Key('workspace_ideas_button')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('desktop_search'))).controller!.text, 'Idea');
  });

  testWidgets('empty Ideas has the capture message', (tester) async {
    await _pumpDesktop(tester);
    await _ideas(tester);
    expect(find.text('No ideas yet. Press + to capture one.'), findsWidgets);
  });

  testWidgets('Control Alt I switches to Ideas and creates an idea', (tester) async {
    final repository = await _pumpDesktop(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect((await repository.getAllNotes()).single.workspace, Note.ideasWorkspace);
  });

  testWidgets('Ship to agent opens a panel containing nested pages in its brief', (tester) async {
    await _pumpDesktop(tester, notes: [_note('root', 'Root', workspace: Note.ideasWorkspace, content: 'Goal'), _note('child', 'Child', workspace: Note.ideasWorkspace, parentId: 'root', content: 'Detail')]);
    await _ideas(tester);
    await tester.tap(find.text('Ship to agent'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop_panel')), findsOneWidget);
    expect(find.text('Ship to an agent'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('idea_brief_field'))).controller!.text, contains('### Child'));
  });

  testWidgets('agent command and copying brief update clipboard and handoff', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final repository = await _pumpDesktop(tester, notes: [_note('root', 'Root', workspace: Note.ideasWorkspace, content: 'Goal')]);
    await _ideas(tester);
    await tester.tap(find.text('Ship to agent'));
    await tester.pumpAndSettle();
    final codex = find.textContaining('codex');
    await tester.tap(find.text('Claude Code'));
    await tester.pump();
    expect(codex, findsNothing);
    await tester.tap(find.text('Copy brief'));
    await tester.pumpAndSettle();
    expect(copied, contains('# Root'));
    expect((await repository.getNote('root'))!.handedOffTo, 'Claude Code');
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('Handed off to Claude Code on'), findsOneWidget);
  });

  testWidgets('edited brief text is what Copy brief writes', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _pumpDesktop(tester, notes: [_note('root', 'Root', workspace: Note.ideasWorkspace)]);
    await _ideas(tester);
    await tester.tap(find.text('Ship to agent'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('idea_brief_field')), 'Edited brief');
    await tester.tap(find.text('Copy brief'));
    await tester.pumpAndSettle();
    expect(copied, 'Edited brief');
  });

  test('review and glossary source helper keeps ideas out', () {
    final sources = inWorkspace([_note('note', 'Note'), _note('idea', 'Idea', workspace: Note.ideasWorkspace)], Note.notesWorkspace);
    expect(sources.single.id, 'note');
  });
}
