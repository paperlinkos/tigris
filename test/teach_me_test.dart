import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/preferences_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/screens/note_detail_screen.dart';
import 'package:tigris/screens/teach_me_screen.dart';
import 'package:tigris/services/local_ai_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    required PreferencesStorage storage,
    required LocalNoteRepository noteRepo,
    required LocalReviewRepository reviewRepo,
    required Widget child,
    LocalAiService aiService = const LocalAiService(),
  }) {
    return RepositoryScope(
      noteRepository: noteRepo,
      reviewRepository: reviewRepo,
      aiService: aiService,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('Phase 9 — Teach Me Tests', () {
    testWidgets('TeachMeScreen loads question, accepts answer, provides feedback, and completes session', (tester) async {
      final storage = PreferencesStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      await tester.pumpWidget(
        buildTestApp(
          storage: storage,
          noteRepo: noteRepo,
          reviewRepo: reviewRepo,
          child: const TeachMeScreen(
            noteId: 'note_teach_1',
            noteTitle: 'Mental Models',
            noteContent: 'First principles thinking is the act of boiling a process down to the fundamental truths. Inversion looks at problems backwards to reveal hidden risks.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header & initial question loaded
      expect(find.text('TEACH ME'), findsOneWidget);
      expect(find.text('Mental Models'), findsOneWidget);
      expect(find.textContaining('First principles thinking is'), findsOneWidget);

      // Verify input bar
      final inputField = find.byKey(const Key('teach_me_input_field'));
      expect(inputField, findsOneWidget);
      final submitButton = find.byKey(const Key('submit_teach_me_answer_button'));
      expect(submitButton, findsOneWidget);

      // Enter first answer
      await tester.enterText(inputField, 'It means breaking things down to their foundational truths rather than reasoning by analogy.');
      await tester.pumpAndSettle();

      // Submit first answer
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify user answer bubble & AI evaluation
      expect(find.text('YOU'), findsOneWidget);
      expect(find.textContaining('breaking things down to their foundational truths'), findsOneWidget);
      expect(find.text('Understood'), findsOneWidget);
      expect(find.textContaining('Great retrieval'), findsOneWidget);

      // Follow-up question should now be visible
      expect(find.textContaining('Follow-up: How would you apply this principle'), findsOneWidget);

      // Enter second answer to complete the session
      await tester.enterText(inputField, 'By questioning assumptions when designing architectural boundaries.');
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Should transition to completion summary
      expect(find.text('Session complete'), findsOneWidget);
      expect(find.textContaining('You actively recalled concepts from'), findsOneWidget);
      expect(find.byKey(const Key('teach_me_done_button')), findsOneWidget);

      // Verify review recorded in repository
      final reviews = await reviewRepo.getAllReviews();
      expect(reviews.isNotEmpty, isTrue);

      // Tap Done
      await tester.tap(find.byKey(const Key('teach_me_done_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('Error during generation shows retry button and recovers', (tester) async {
      final storage = PreferencesStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      await tester.pumpWidget(
        buildTestApp(
          storage: storage,
          noteRepo: noteRepo,
          reviewRepo: reviewRepo,
          aiService: const LocalAiService(shouldSimulateFailure: true),
          child: const TeachMeScreen(
            noteId: 'note_err_1',
            noteTitle: 'Error Test',
            noteContent: 'Sample content.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error state displayed
      expect(find.text('Could not begin session'), findsOneWidget);
      expect(find.byKey(const Key('retry_teach_me_button')), findsOneWidget);
    });

    testWidgets('Launching Teach Me from NoteDetailScreen sheet opens TeachMeScreen', (tester) async {
      final storage = PreferencesStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      final note = Note(
        id: 'note_teach_flow',
        title: 'Deep Architecture',
        content: 'Clean architecture isolates core domain logic from framework dependencies.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(note);

      await tester.pumpWidget(
        buildTestApp(
          storage: storage,
          noteRepo: noteRepo,
          reviewRepo: reviewRepo,
          child: NoteDetailScreen(
            noteId: note.id,
            initialNote: note,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open AI actions
      await tester.tap(find.text('✦ AI'));
      await tester.pumpAndSettle();

      // Scroll to Teach Me and tap
      expect(find.text('Teach Me'), findsOneWidget);
      await tester.ensureVisible(find.text('Teach Me'));
      await tester.tap(find.text('Teach Me'));
      await tester.pumpAndSettle();

      // Verified inside TeachMeScreen
      expect(find.text('TEACH ME'), findsOneWidget);
      expect(find.text('Deep Architecture'), findsOneWidget);
      expect(find.byKey(const Key('teach_me_input_field')), findsOneWidget);
    });
  });
}
