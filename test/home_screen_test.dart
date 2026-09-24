import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/screens/home_screen.dart';

void main() {
  group('HomeScreen Tests', () {
    testWidgets('Renders greeting, empty memory state, and empty notes state', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      bool createNoteTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            child: HomeScreen(
              onCreateNote: () {
                createNoteTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header Toggle & FAB Action
      expect(find.text('Notes'), findsWidgets);
      expect(find.byKey(const Key('home_fab_menu')), findsOneWidget);

      // Verify Section: NOTES (Empty State)
      expect(find.text('NOTES'), findsOneWidget);
      expect(find.text('Your notes will appear here.'), findsOneWidget);
      expect(find.text('Create your first note'), findsOneWidget);

      // Tap FAB to open drop-up menu, then tap "New note"
      await tester.tap(find.byKey(const Key('home_fab_menu')));
      await tester.pumpAndSettle();
      expect(find.text('New note'), findsOneWidget);
      await tester.tap(find.text('New note'));
      await tester.pump();
      expect(createNoteTapped, isTrue);

      // Tap "Create your first note" text action
      createNoteTapped = false;
      await tester.tap(find.text('Create your first note'));
      await tester.pump();
      expect(createNoteTapped, isTrue);
    });

    testWidgets('Renders items when real data exists in repositories', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      // Seed 1 real note
      await noteRepo.saveNote(
        Note(
          id: 'note_1',
          title: 'Epictetus Enchiridion',
          subtitle: 'Core precepts on freedom',
          content: 'Some things are in our control...',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Notes section
      expect(find.text('NOTES'), findsOneWidget);

      // Recent square cards + Notes list display the note
      expect(find.text('Epictetus Enchiridion'), findsNWidgets(2)); // square card + notes list item
      expect(find.text('Some things are in our control...'), findsOneWidget);
    });

    testWidgets('HomeScreen updates immediately when notes are created, edited, and deleted via reactive stream', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially empty
      expect(find.text('Your notes will appear here.'), findsOneWidget);

      // 1. Create note in repository directly
      final note = Note(
        id: 'realtime_note_1',
        title: 'Reactive Architecture',
        content: 'Streams provide seamless real-time UI updates.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(note);
      await tester.pumpAndSettle(); // Deliver stream event and rebuild

      // Verify it immediately appears on HomeScreen without navigation
      expect(find.text('Reactive Architecture'), findsWidgets);
      expect(find.text('Your notes will appear here.'), findsNothing);

      // 2. Edit note in repository
      final edited = note.copyWith(
        title: 'Reactive Architecture v2',
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(edited);
      await tester.pumpAndSettle(); // Deliver stream event and rebuild

      // Verify title immediately updates
      expect(find.text('Reactive Architecture v2'), findsWidgets);
      expect(find.text('Reactive Architecture'), findsNothing);

      // 3. Delete note in repository
      await noteRepo.deleteNote(note.id);
      await tester.pumpAndSettle(); // Deliver stream event and rebuild

      // Verify note is gone and empty state reappears
      expect(find.text('Reactive Architecture v2'), findsNothing);
      expect(find.text('Your notes will appear here.'), findsOneWidget);
    });
  });
}
