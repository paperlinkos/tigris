import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/screens/note_detail_screen.dart';
import 'package:tigris/screens/notes_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3 — Note Editor Tests', () {
    testWidgets('Edit title, subtitle, and body inline with debounced autosave and back navigation', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      final initialNote = Note(
        id: 'editor_test_note',
        title: 'Initial Title',
        subtitle: 'Initial Subtitle',
        content: 'Initial Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(initialNote);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            child: NoteDetailScreen(
              noteId: 'editor_test_note',
              initialNote: initialNote,
              noteRepository: noteRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify text fields display initial values
      expect(find.text('Initial Title'), findsOneWidget);
      expect(find.text('Initial Subtitle'), findsOneWidget);
      expect(find.text('Initial Content'), findsOneWidget);

      // Edit title, subtitle, and body
      await tester.enterText(find.byType(TextField).at(0), 'Reflections on Craft');
      await tester.enterText(find.byType(TextField).at(1), 'On deliberate practice and stillness');
      await tester.enterText(find.byType(TextField).at(2), 'True mastery requires deep focus and continuous self-examination.');

      // Wait for debounce autosave timer (600ms)
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Verify persisted note in repository reflects the edits
      final updatedNote = await noteRepo.getNote('editor_test_note');
      expect(updatedNote, isNotNull);
      expect(updatedNote!.title, equals('Reflections on Craft'));
      expect(updatedNote.subtitle, equals('On deliberate practice and stillness'));
      expect(updatedNote.content, equals('True mastery requires deep focus and continuous self-examination.'));
    });

    testWidgets('Navigate away, return, edit again, and verify persistence', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      final initialNote = Note(
        id: 'note_nav_test',
        title: 'Draft A',
        content: 'Paragraph 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(initialNote);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            child: const NotesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open note from Notes list
      expect(find.text('Draft A'), findsOneWidget);
      await tester.tap(find.text('Draft A'));
      await tester.pumpAndSettle();

      // 2. Edit content in NoteDetailScreen
      await tester.enterText(find.byType(TextField).at(2), 'Paragraph 1\nParagraph 2 with new reflections.');

      // 3. Navigate away immediately via back button (triggers safe back save)
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // 4. We are back on NotesScreen
      expect(find.text('NOTES'), findsOneWidget);

      // Verify persistence in repository
      var persisted = await noteRepo.getNote('note_nav_test');
      expect(persisted!.content, contains('Paragraph 2 with new reflections.'));

      // 5. Re-open note and verify content loaded
      await tester.tap(find.text('Draft A'));
      await tester.pumpAndSettle();
      expect(find.text('Paragraph 1\nParagraph 2 with new reflections.'), findsOneWidget);

      // 6. Edit title and add child page from inside editor (full-screen page)
      await tester.enterText(find.byType(TextField).at(0), 'Published Mastery');
      await tester.tap(find.text('Add page'));
      await tester.pumpAndSettle();

      expect(find.byType(NoteDetailScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Sub-discipline 1');
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      // Return from subpage
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // Verify subpage appears beneath content
      expect(find.text('Sub-discipline 1'), findsOneWidget);

      // Open subpage
      await tester.tap(find.text('Sub-discipline 1'));
      await tester.pumpAndSettle();

      // Verify subpage editor
      expect(find.text('Sub-discipline 1'), findsOneWidget);

      // Return from subpage
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // Return to Notes list
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      expect(find.text('Published Mastery'), findsOneWidget);
    });

    testWidgets('Empty untitled note defaults safely to Untitled upon save', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      final note = Note(
        id: 'empty_title_note',
        title: 'Original Title',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(note);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            child: NoteDetailScreen(
              noteId: 'empty_title_note',
              initialNote: note,
              noteRepository: noteRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear title field completely
      await tester.enterText(find.byType(TextField).at(0), '   ');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      final saved = await noteRepo.getNote('empty_title_note');
      expect(saved!.title, equals('Untitled'));
    });
  });
}
