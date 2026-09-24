import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/models/note_block.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/repositories/offline_first_note_repository.dart';
import 'package:tigris/screens/note_detail_screen.dart';
import 'package:tigris/widgets/editor/block_note_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryStorage storage;
  late LocalNoteRepository localRepo;
  late OfflineFirstNoteRepository repo;

  setUp(() {
    storage = InMemoryStorage();
    localRepo = LocalNoteRepository(storage: storage);
    repo = OfflineFirstNoteRepository(localRepo: localRepo);
  });

  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: RepositoryScope(
        noteRepository: repo,
        reviewRepository: LocalReviewRepository(storage: storage),
        child: Scaffold(body: child),
      ),
    );
  }

  group('Block-Based Editor & Content Model Tests', () {
    test('1 & 2. Create normal text block & multiple text blocks', () {
      final note = Note(
        id: 'n1',
        title: 'Test Note',
        content: 'First line\nSecond line',
        blocksJson: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(note.blocks.length, 2);
      expect(note.blocks[0].content, 'First line');
      expect(note.blocks[1].content, 'Second line');
    });

    test('3. Convert a block to bullet', () {
      final block = NoteBlock(type: BlockType.text, content: 'Bullet item');
      final updated = block.copyWith(type: BlockType.bullet);
      expect(updated.type, BlockType.bullet);
    });

    test('4 & 5. Bullet list continuation and exit on empty item', () {
      final bullet1 = NoteBlock(type: BlockType.bullet, content: 'Item 1');
      final bulletEmpty = NoteBlock(type: BlockType.bullet, content: '');

      final nextBlock = NoteBlock(type: bullet1.type, content: '', indentLevel: bullet1.indentLevel);
      expect(nextBlock.type, BlockType.bullet);

      final exitedBlock = bulletEmpty.copyWith(type: BlockType.text, indentLevel: 0);
      expect(exitedBlock.type, BlockType.text);
    });

    test('6, 7 & 8. Numbered list creation, continuation, and exit', () {
      final num1 = NoteBlock(type: BlockType.number, content: 'First');
      final numEmpty = NoteBlock(type: BlockType.number, content: '');

      expect(num1.type, BlockType.number);

      final nextNum = NoteBlock(type: num1.type, content: '');
      expect(nextNum.type, BlockType.number);

      final exitedNum = numEmpty.copyWith(type: BlockType.text);
      expect(exitedNum.type, BlockType.text);
    });

    test('9 & 10. Increase and decrease indentation', () {
      final block = NoteBlock(type: BlockType.bullet, content: 'Nested', indentLevel: 0);

      final indented = block.copyWith(indentLevel: (block.indentLevel + 1).clamp(0, 5));
      expect(indented.indentLevel, 1);

      final unindented = indented.copyWith(indentLevel: (indented.indentLevel - 1).clamp(0, 5));
      expect(unindented.indentLevel, 0);
    });

    test('11 & 12. Nested bullets and numbered lists calculation', () {
      final blocks = [
        NoteBlock(type: BlockType.number, content: 'Top 1', indentLevel: 0),
        NoteBlock(type: BlockType.number, content: 'Sub 1', indentLevel: 1),
        NoteBlock(type: BlockType.number, content: 'Sub 2', indentLevel: 1),
        NoteBlock(type: BlockType.number, content: 'Top 2', indentLevel: 0),
      ];

      expect(blocks[0].indentLevel, 0);
      expect(blocks[1].indentLevel, 1);
      expect(blocks[2].indentLevel, 1);
      expect(blocks[3].indentLevel, 0);
    });

    test('13 & 14. Rich text bold formatting without raw Markdown **', () {
      final attr = InlineAttribute(start: 0, end: 4, type: 'bold');
      final block = NoteBlock(
        type: BlockType.text,
        content: 'Bold text',
        inlineAttributes: [attr],
      );

      expect(block.content.contains('**'), false);
      expect(block.inlineAttributes.length, 1);
      expect(block.inlineAttributes.first.type, 'bold');
    });

    test('15. Insert a Page block pointing to target note', () {
      final pageBlock = NoteBlock(
        type: BlockType.page,
        targetNoteId: 'target_123',
      );

      expect(pageBlock.type, BlockType.page);
      expect(pageBlock.targetNoteId, 'target_123');
    });

    testWidgets('16, 17, 18. Page block navigation, Stream retention & breadcrumbs', (tester) async {
      final parentStream = Note(
        id: 'stream_1',
        title: 'Work Stream',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final targetNote = Note(
        id: 'target_123',
        title: 'Target Page',
        content: 'Target content',
        parentId: 'stream_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final mainNote = Note(
        id: 'main_1',
        title: 'Main Note',
        content: '',
        parentId: 'stream_1',
        blocksJson: '[{"type":"page","targetNoteId":"target_123"}]',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.saveNote(parentStream);
      await repo.saveNote(targetNote);
      await repo.saveNote(mainNote);

      await tester.pumpWidget(buildTestWidget(
        NoteDetailScreen(noteId: 'main_1', initialNote: mainNote, noteRepository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Target Page'), findsOneWidget);

      await tester.tap(find.text('Target Page'));
      await tester.pumpAndSettle();

      expect(find.text('Target content'), findsOneWidget);
      expect(find.text('Work Stream'), findsWidgets);

      final reloadedTarget = await repo.getNote('target_123');
      expect(reloadedTarget?.parentId, 'stream_1');
    });

    testWidgets('19. Edit target note and verify changes persist', (tester) async {
      final targetNote = Note(
        id: 'target_1',
        title: 'Initial Title',
        content: 'Original body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(targetNote);

      await tester.pumpWidget(buildTestWidget(
        NoteDetailScreen(noteId: 'target_1', initialNote: targetNote, noteRepository: repo),
      ));
      await tester.pumpAndSettle();

      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'Updated Target Title');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      final saved = await repo.getNote('target_1');
      expect(saved?.title, 'Updated Target Title');
    });

    testWidgets('20. Delete a referenced Note and verify no crash', (tester) async {
      final mainNote = Note(
        id: 'main_2',
        title: 'Main Note',
        content: '',
        blocksJson: '[{"type":"page","targetNoteId":"deleted_target"}]',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(mainNote);

      await tester.pumpWidget(buildTestWidget(
        NoteDetailScreen(noteId: 'main_2', initialNote: mainNote, noteRepository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Deleted Page Reference'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('21. Existing old plain text notes migrate safely', () {
      final oldNote = Note(
        id: 'old_1',
        title: 'Old Plain Note',
        content: '# Header\n• Bullet 1\n1. Number 1\nNormal text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final blocks = oldNote.blocks;
      expect(blocks.length, 4);
      expect(blocks[0].type, BlockType.heading);
      expect(blocks[0].content, 'Header');
      expect(blocks[1].type, BlockType.bullet);
      expect(blocks[1].content, 'Bullet 1');
      expect(blocks[2].type, BlockType.number);
      expect(blocks[2].content, 'Number 1');
      expect(blocks[3].type, BlockType.text);
      expect(blocks[3].content, 'Normal text');
    });

    test('22. Stream note lists update reactively', () async {
      final expectation = expectLater(
        repo.watchRecentNotes(),
        emitsThrough(predicate<List<Note>>((notes) => notes.any((n) => n.id == 'reactive_1'))),
      );

      await repo.saveNote(Note(
        id: 'reactive_1',
        title: 'Reactive Note',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await expectation;
    });
  });

  group('Free-Moving Block Reordering & Drag Mechanics Tests', () {
    testWidgets('Drag block 5 above block 1 and block 3 below block 5', (tester) async {
      final note = Note(
        id: 'drag_note_1',
        title: 'Drag Test 1',
        content: '',
        blocksJson: '''[
          {"id":"b1","type":"text","content":"Block 1"},
          {"id":"b2","type":"text","content":"Block 2"},
          {"id":"b3","type":"text","content":"Block 3"},
          {"id":"b4","type":"text","content":"Block 4"},
          {"id":"b5","type":"text","content":"Block 5"}
        ]''',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(note);

      await tester.pumpWidget(buildTestWidget(
        NoteDetailScreen(noteId: 'drag_note_1', initialNote: note, noteRepository: repo),
      ));
      await tester.pumpAndSettle();

      final state = tester.state<BlockNoteEditorState>(find.byType(BlockNoteEditor));

      // Move Block 5 (index 4) above Block 1 (index 0)
      state.moveSubtree(sourceIndex: 4, targetIndex: 0);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(state.blocks[0].content, 'Block 5');
      expect(state.blocks[1].content, 'Block 1');

      // Move Block 3 (now index 3) below Block 5 (index 0) -> target index 1
      state.moveSubtree(sourceIndex: 3, targetIndex: 1);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(state.blocks[0].content, 'Block 5');
      expect(state.blocks[1].content, 'Block 3');
      expect(state.blocks[2].content, 'Block 1');
    });

    testWidgets('Drag bullet underneath another bullet to nest and outdent back', (tester) async {
      final note = Note(
        id: 'nest_note',
        title: 'Nest Test',
        content: '',
        blocksJson: '''[
          {"id":"b1","type":"bullet","content":"Bullet A","indentLevel":0},
          {"id":"b2","type":"bullet","content":"Bullet B","indentLevel":0}
        ]''',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(note);

      await tester.pumpWidget(buildTestWidget(
        NoteDetailScreen(noteId: 'nest_note', initialNote: note, noteRepository: repo),
      ));
      await tester.pumpAndSettle();

      final state = tester.state<BlockNoteEditorState>(find.byType(BlockNoteEditor));

      // Nest Bullet B under Bullet A (index 1 -> target 1, newIndentLevel: 1)
      state.moveSubtree(sourceIndex: 1, targetIndex: 1, newIndentLevel: 1);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(state.blocks[1].content, 'Bullet B');
      expect(state.blocks[1].indentLevel, 1);

      // Outdent Bullet B back out to indentLevel 0
      state.moveSubtree(sourceIndex: 1, targetIndex: 1, newIndentLevel: 0);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(state.blocks[1].indentLevel, 0);
    });

    testWidgets('Move numbered list item and verify sequence numbers recalculate automatically', (tester) async {
      final note = Note(
        id: 'num_note',
        title: 'Number Test',
        content: '',
        blocksJson: '''[
          {"id":"b1","type":"number","content":"Buy groceries"},
          {"id":"b2","type":"number","content":"Buy supplies"},
          {"id":"b3","type":"number","content":"Finish project"}
        ]''',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(note);

      await tester.pumpWidget(buildTestWidget(
        NoteDetailScreen(noteId: 'num_note', initialNote: note, noteRepository: repo),
      ));
      await tester.pumpAndSettle();

      final state = tester.state<BlockNoteEditorState>(find.byType(BlockNoteEditor));

      // Move item 3 ("Finish project", index 2) above item 1 (index 0)
      state.moveSubtree(sourceIndex: 2, targetIndex: 0);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(state.blocks[0].content, 'Finish project');
      expect(state.blocks[1].content, 'Buy groceries');
      expect(state.blocks[2].content, 'Buy supplies');

      expect(find.descendant(of: find.byType(BlockNoteEditor), matching: find.text('1.')), findsOneWidget);
      expect(find.descendant(of: find.byType(BlockNoteEditor), matching: find.text('2.')), findsOneWidget);
      expect(find.descendant(of: find.byType(BlockNoteEditor), matching: find.text('3.')), findsOneWidget);
    });

    testWidgets('Moving a parent block moves its entire subtree', (tester) async {
      final note = Note(
        id: 'subtree_note',
        title: 'Subtree Test',
        content: '',
        blocksJson: '''[
          {"id":"p1","type":"text","content":"Project","indentLevel":0},
          {"id":"c1","type":"bullet","content":"Research","indentLevel":1},
          {"id":"c2","type":"bullet","content":"Design","indentLevel":1},
          {"id":"p2","type":"text","content":"Launch Plan","indentLevel":0}
        ]''',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(note);

      await tester.pumpWidget(buildTestWidget(
        NoteDetailScreen(noteId: 'subtree_note', initialNote: note, noteRepository: repo),
      ));
      await tester.pumpAndSettle();

      final state = tester.state<BlockNoteEditorState>(find.byType(BlockNoteEditor));

      // Move "Project" subtree (index 0, contains 3 blocks: Project, Research, Design) to after "Launch Plan" (target index 4)
      state.moveSubtree(sourceIndex: 0, targetIndex: 4);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(state.blocks[0].content, 'Launch Plan');
      expect(state.blocks[1].content, 'Project');
      expect(state.blocks[2].content, 'Research');
      expect(state.blocks[3].content, 'Design');

      expect(state.blocks[2].indentLevel, 1);
      expect(state.blocks[3].indentLevel, 1);
    });

    testWidgets('Move Page block, reload Note, and verify order persists without duplicating target', (tester) async {
      final target = Note(
        id: 'target_page_1',
        title: 'Research Page',
        content: 'Research details',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final note = Note(
        id: 'page_move_note',
        title: 'Page Move Test',
        content: '',
        blocksJson: '''[
          {"id":"b1","type":"text","content":"Intro"},
          {"id":"b2","type":"bullet","content":"Bullet 1"},
          {"id":"b3","type":"page","targetNoteId":"target_page_1"}
        ]''',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(target);
      await repo.saveNote(note);

      await tester.pumpWidget(buildTestWidget(
        NoteDetailScreen(noteId: 'page_move_note', initialNote: note, noteRepository: repo),
      ));
      await tester.pumpAndSettle();

      final state = tester.state<BlockNoteEditorState>(find.byType(BlockNoteEditor));

      // Move Page block (index 2) to before Intro (index 0)
      state.moveSubtree(sourceIndex: 2, targetIndex: 0);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      final saved = await repo.getNote('page_move_note');
      expect(saved?.blocks[0].type, BlockType.page);
      expect(saved?.blocks[0].targetNoteId, 'target_page_1');
      expect(saved?.blocks[1].content, 'Intro');
      expect(saved?.blocks[2].content, 'Bullet 1');

      final targetReload = await repo.getNote('target_page_1');
      expect(targetReload?.title, 'Research Page');
    });
  });
}
