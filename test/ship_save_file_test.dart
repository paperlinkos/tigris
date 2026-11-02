import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/widgets/ideas/ship_to_agent_panel.dart';

void main() {
  late LocalNoteRepository repository;
  late Note idea;

  setUp(() async {
    repository = LocalNoteRepository(storage: InMemoryStorage());
    idea = Note(
      id: 'idea',
      title: 'Big plan',
      content: 'Do it',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      workspace: Note.ideasWorkspace,
      ideaStatus: 'Ready',
    );
    await repository.saveNote(idea);
  });

  Future<void> pump(WidgetTester tester, Future<bool> Function(String, Uint8List) save) async {
    await tester.pumpWidget(MaterialApp(
      home: ShipToAgentPanel(root: idea, notes: [idea], repository: repository, onSaveFile: save),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Save as file passes the edited brief and marks the idea handed off', (tester) async {
    String? name;
    Uint8List? bytes;
    await pump(tester, (n, b) async {
      name = n;
      bytes = b;
      return true;
    });
    await tester.enterText(find.byKey(const Key('idea_brief_field')), 'Edited brief');
    await tester.tap(find.byKey(const Key('save_brief_file')));
    await tester.pumpAndSettle();
    expect(name, 'big-plan.md');
    expect(utf8.decode(bytes!), 'Edited brief');
    final saved = (await repository.getNote('idea'))!;
    expect(saved.ideaStatus, 'Handed off');
    expect(saved.handedOffTo, 'Codex');
  });

  testWidgets('Cancelling the save dialog changes nothing', (tester) async {
    await pump(tester, (n, b) async => false);
    await tester.tap(find.byKey(const Key('save_brief_file')));
    await tester.pumpAndSettle();
    final saved = (await repository.getNote('idea'))!;
    expect(saved.ideaStatus, 'Ready');
    expect(saved.handedOffTo, isNull);
    expect(find.text('Brief saved'), findsNothing);
  });
}
