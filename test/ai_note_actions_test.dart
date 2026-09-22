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
import 'package:tigris/services/local_ai_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 6 — AI Note Actions Tests', () {
    testWidgets('AI button opens sheet, runs summarize, explain, flashcards, and quiz without altering note', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);
      const aiService = LocalAiService();

      const originalContent =
          'Spaced repetition leverages the spacing effect to optimize long-term memory consolidation. '
          'Active recall forces the neural retrieval pathway to strengthen synaptic connections.';

      final note = Note(
        id: 'ai_action_note',
        title: 'Memory Consolidation',
        subtitle: 'Neurobiology of learning',
        content: originalContent,
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
            aiService: aiService,
            child: NoteDetailScreen(
              noteId: 'ai_action_note',
              initialNote: note,
              noteRepository: noteRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify ✦ AI action button exists
      expect(find.text('✦ AI'), findsOneWidget);

      // 2. Tap ✦ AI to open sheet
      await tester.tap(find.text('✦ AI'));
      await tester.pumpAndSettle();

      expect(find.text('✦ AI REFLECTION'), findsOneWidget);
      expect(find.text('Summarize'), findsOneWidget);
      expect(find.text('Create flashcards'), findsOneWidget);
      expect(find.text('Create quiz'), findsOneWidget);
      expect(find.text('Explain simply'), findsOneWidget);

      // 3. Test Summarize
      await tester.tap(find.text('Summarize'));
      await tester.pumpAndSettle();

      expect(find.text('✦ SUMMARY'), findsOneWidget);
      expect(find.text('KEY POINTS'), findsOneWidget);

      // Return to AI menu
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
      await tester.pumpAndSettle();

      // 4. Test Flashcards
      await tester.tap(find.text('Create flashcards'));
      await tester.pumpAndSettle();

      expect(find.text('✦ FLASHCARDS'), findsOneWidget);
      expect(find.textContaining('cards generated from this note'), findsOneWidget);

      // Return to AI menu
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
      await tester.pumpAndSettle();

      // 5. Test Quiz
      await tester.tap(find.text('Create quiz'));
      await tester.pumpAndSettle();

      expect(find.text('✦ QUIZ'), findsOneWidget);
      expect(find.textContaining('questions generated from this note'), findsOneWidget);

      // Return to AI menu
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
      await tester.pumpAndSettle();

      // 6. Test Explain simply
      await tester.ensureVisible(find.text('Explain simply'));
      await tester.tap(find.text('Explain simply'));
      await tester.pumpAndSettle();

      expect(find.text('✦ EXPLAIN'), findsOneWidget);
      expect(find.textContaining('In simple terms'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Verify original note content remains completely unchanged
      final reloadedNote = await noteRepo.getNote('ai_action_note');
      expect(reloadedNote!.content, equals(originalContent));
    });

    testWidgets('Empty note warning and error retry flow', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      final emptyNote = Note(
        id: 'empty_note',
        title: 'Empty Thoughts',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(emptyNote);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            child: NoteDetailScreen(
              noteId: 'empty_note',
              initialNote: emptyNote,
              noteRepository: noteRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap ✦ AI button on empty note
      await tester.tap(find.text('✦ AI'));
      await tester.pumpAndSettle();

      // Tap Summarize
      await tester.tap(find.text('Summarize'));
      await tester.pumpAndSettle();

      // Expect helpful empty content notice
      expect(find.textContaining('Add some content to this note'), findsOneWidget);
    });
  });
}
