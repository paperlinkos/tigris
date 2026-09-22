import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/flashcard.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/models/quiz.dart';
import 'package:tigris/models/review_item.dart';
import 'package:tigris/persistence/preferences_storage.dart';
import 'package:tigris/repositories/local_flashcard_repository.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_quiz_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/screens/flashcard_review_screen.dart';
import 'package:tigris/screens/home_screen.dart';
import 'package:tigris/screens/note_detail_screen.dart';
import 'package:tigris/screens/notes_screen.dart';
import 'package:tigris/screens/quiz_screen.dart';
import 'package:tigris/screens/review_session_screen.dart';
import 'package:tigris/screens/teach_me_screen.dart';
import 'package:tigris/services/local_ai_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final viewports = <String, Size>{
    'iPhone SE (375x667)': const Size(375, 667),
    'iPhone Standard (390x844)': const Size(390, 844),
    'iPhone Pro Max (430x932)': const Size(430, 932),
    'Android Compact (360x800)': const Size(360, 800),
  };

  group('Phase 12 — Multi-Viewport Zero-Overflow Audit Across All Screens', () {
    for (final entry in viewports.entries) {
      testWidgets('Zero overflow on ${entry.key} for all interactive screens', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final storage = PreferencesStorage();
        final noteRepo = LocalNoteRepository(storage: storage);
        final reviewRepo = LocalReviewRepository(storage: storage);
        final flashcardRepo = LocalFlashcardRepository(storage: storage);
        final quizRepo = LocalQuizRepository(storage: storage);

        final longText = 'This is an exceptionally long paragraph designed to test typographical integrity and prevent horizontal or vertical overflow across varied screen sizes. ' * 8;

        final testNote = Note(
          id: 'vp_note_1',
          title: 'Comprehensive Systems Thinking Architecture',
          subtitle: 'An exhaustive exploration into resilient feedback loops and operational leverage',
          content: longText,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await noteRepo.saveNote(testNote);

        final cards = [
          Flashcard(
            id: 'fc_vp_1',
            noteId: testNote.id,
            front: 'What is the governing principle of positive feedback loops in complex systems?',
            back: 'Positive feedback amplifies initial fluctuations until systemic constraints are encountered.',
            createdAt: DateTime.now(),
          ),
        ];
        await flashcardRepo.saveFlashcards(cards);

        final questions = [
          QuizQuestion(
            id: 'qz_vp_1',
            noteId: testNote.id,
            prompt: 'Which phenomenon occurs when feedback loops exceed capacity constraints?',
            options: [
              'Systemic bifurcation and non-linear phase transitions.',
              'Linear acceleration with invariant boundaries.',
              'Immediate equilibrium return.',
              'Total system evaporation.',
            ],
            correctOptionIndex: 0,
            explanation: 'Complex systems manifest phase transitions under stress.',
          ),
        ];
        await quizRepo.saveQuizQuestions(questions);

        final review = ReviewItem(
          id: 'rev_vp_1',
          noteId: testNote.id,
          dueAt: DateTime.now().subtract(const Duration(minutes: 10)),
          intervalDays: 1,
          repetitionCount: 0,
          easeFactor: 2.5,
        );
        await reviewRepo.saveReview(review);

        Widget wrap(Widget screen) {
          return RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            flashcardRepository: flashcardRepo,
            quizRepository: quizRepo,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: screen,
            ),
          );
        }

        // 1. Home Screen
        await tester.pumpWidget(wrap(const HomeScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 2. Notes Screen
        await tester.pumpWidget(wrap(const NotesScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 3. Note Detail Screen (with long text)
        await tester.pumpWidget(wrap(NoteDetailScreen(noteId: testNote.id, initialNote: testNote)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 4. Flashcard Review Screen
        await tester.pumpWidget(wrap(FlashcardReviewScreen(
          flashcards: cards,
          noteId: testNote.id,
          noteTitle: testNote.title,
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Reveal answer and rate
        await tester.tap(find.byKey(const Key('show_answer_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 5. Quiz Screen
        await tester.pumpWidget(wrap(QuizScreen(
          questions: questions,
          noteId: testNote.id,
          noteTitle: testNote.title,
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 6. Teach Me Screen
        await tester.pumpWidget(wrap(TeachMeScreen(
          noteId: testNote.id,
          noteTitle: testNote.title,
          noteContent: testNote.content,
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 7. Review Session Screen
        await tester.pumpWidget(wrap(const ReviewSessionScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    test('Deeply nested notes persistence and subtree verification', () async {
      final storage = PreferencesStorage();
      final noteRepo = LocalNoteRepository(storage: storage);

      // Level 1: Business
      final business = Note(
        id: 'n_biz',
        title: 'Business',
        content: 'Root level company thoughts',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(business);

      // Level 2: Ideas
      final ideas = Note(
        id: 'n_ideas',
        parentId: business.id,
        title: 'Ideas',
        content: 'Incubation ventures',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(ideas);

      // Level 3: Smart Q Estates
      final estates = Note(
        id: 'n_estates',
        parentId: ideas.id,
        title: 'Smart Q Estates',
        content: 'Property tech venture',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(estates);

      // Level 4: Service Apartments
      final apts = Note(
        id: 'n_apts',
        parentId: estates.id,
        title: 'Service Apartments',
        content: 'Short let luxury operational strategy',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(apts);

      // Verify arbitrary depth tree
      final roots = await noteRepo.getRootNotes();
      expect(roots.any((n) => n.id == business.id), isTrue);

      final ideasChildren = await noteRepo.getChildNotes(ideas.id);
      expect(ideasChildren.length, 1);
      expect(ideasChildren.first.title, 'Smart Q Estates');

      final estateChildren = await noteRepo.getChildNotes(estates.id);
      expect(estateChildren.length, 1);
      expect(estateChildren.first.title, 'Service Apartments');

      // Verify simulated app restart persistence
      final restartedRepo = LocalNoteRepository(storage: storage);
      final reloadedApts = await restartedRepo.getNote(apts.id);
      expect(reloadedApts, isNotNull);
      expect(reloadedApts!.parentId, estates.id);
      expect(reloadedApts.title, 'Service Apartments');

      // Test safe recursive subtree deletion
      await noteRepo.deleteNote(ideas.id);
      expect(await noteRepo.getNote(ideas.id), isNull);
      expect(await noteRepo.getNote(estates.id), isNull);
      expect(await noteRepo.getNote(apts.id), isNull);
      // Business root remains intact
      expect(await noteRepo.getNote(business.id), isNotNull);
    });

    test('AI service failure recovery simulation', () async {
      const failingService = LocalAiService(shouldSimulateFailure: true);

      expect(
        () => failingService.summarizeNote(noteContent: 'Hello world'),
        throwsA(isA<Exception>()),
      );

      const workingService = LocalAiService(shouldSimulateFailure: false);
      final res = await workingService.summarizeNote(noteContent: 'First sentence here. Second sentence follows.');
      expect(res.summary.isNotEmpty, isTrue);
    });
  });
}
