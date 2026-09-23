import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/persistence/preferences_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/screens/home_screen.dart';
import 'package:tigris/screens/notes_screen.dart';
import 'package:tigris/screens/note_detail_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Nested Notes Hierarchy & Persistence Tests', () {
    test('Create root, child, grandchild, and great-grandchild notes (arbitrary depth)', () async {
      final storage = InMemoryStorage();
      final repo = LocalNoteRepository(storage: storage);

      // 1. Create root note
      final root = Note(
        id: 'note_root',
        title: 'Business',
        content: 'Root business thoughts',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(root);

      // 2. Create child note
      final child = Note(
        id: 'note_child',
        parentId: 'note_root',
        title: 'Ideas',
        content: 'Innovative venture ideas',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(child);

      // 3. Create grandchild note
      final grandchild = Note(
        id: 'note_grandchild',
        parentId: 'note_child',
        title: 'Smart Q Estates',
        content: 'PropTech development',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(grandchild);

      // 4. Create great-grandchild note (arbitrary depth verification)
      final greatGrandchild = Note(
        id: 'note_great_grandchild',
        parentId: 'note_grandchild',
        title: 'Service Apartments',
        content: 'Short-term luxury rentals',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(greatGrandchild);

      // Verify hierarchy structure
      final rootFetched = await repo.getNote('note_root');
      expect(rootFetched, isNotNull);
      expect(rootFetched!.isRoot, isTrue);
      expect(rootFetched.childrenIds, contains('note_child'));

      final childFetched = await repo.getNote('note_child');
      expect(childFetched, isNotNull);
      expect(childFetched!.parentId, equals('note_root'));
      expect(childFetched.childrenIds, contains('note_grandchild'));

      final grandchildFetched = await repo.getNote('note_grandchild');
      expect(grandchildFetched, isNotNull);
      expect(grandchildFetched!.parentId, equals('note_child'));
      expect(grandchildFetched.childrenIds, contains('note_great_grandchild'));

      final greatGrandchildFetched = await repo.getNote('note_great_grandchild');
      expect(greatGrandchildFetched, isNotNull);
      expect(greatGrandchildFetched!.parentId, equals('note_grandchild'));

      // Check root query
      final roots = await repo.getRootNotes();
      expect(roots.length, equals(1));
      expect(roots.first.id, equals('note_root'));

      // Check child queries
      final rootChildren = await repo.getChildNotes('note_root');
      expect(rootChildren.length, equals(1));
      expect(rootChildren.first.title, equals('Ideas'));

      final ideaChildren = await repo.getChildNotes('note_child');
      expect(ideaChildren.length, equals(1));
      expect(ideaChildren.first.title, equals('Smart Q Estates'));
    });

    test('Persist hierarchy and reload from fresh storage instance', () async {
      final storage1 = PreferencesStorage();
      final repo1 = LocalNoteRepository(storage: storage1);

      // Save hierarchy in first session
      await repo1.saveNote(
        Note(
          id: 'root_1',
          title: 'Philosophy',
          content: 'Meditations',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await repo1.saveNote(
        Note(
          id: 'child_1',
          parentId: 'root_1',
          title: 'Stoicism',
          content: 'Epictetus and Seneca',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Simulate app restart: Instantiate a new PreferencesStorage and LocalNoteRepository
      final storage2 = PreferencesStorage();
      final repo2 = LocalNoteRepository(storage: storage2);

      final reloadedRoots = await repo2.getRootNotes();
      expect(reloadedRoots.length, equals(1));
      expect(reloadedRoots.first.title, equals('Philosophy'));
      expect(reloadedRoots.first.childrenIds, contains('child_1'));

      final reloadedChildren = await repo2.getChildNotes('root_1');
      expect(reloadedChildren.length, equals(1));
      expect(reloadedChildren.first.title, equals('Stoicism'));
    });

    test('Safe deletion: recursive subtree deletion removes descendants without orphans', () async {
      final storage = InMemoryStorage();
      final repo = LocalNoteRepository(storage: storage);

      // Build hierarchy: Root -> Child -> Grandchild -> Great-grandchild
      await repo.saveNote(Note(
        id: 'r1',
        title: 'Root',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repo.saveNote(Note(
        id: 'c1',
        parentId: 'r1',
        title: 'Child 1',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repo.saveNote(Note(
        id: 'gc1',
        parentId: 'c1',
        title: 'Grandchild 1',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repo.saveNote(Note(
        id: 'ggc1',
        parentId: 'gc1',
        title: 'Great Grandchild 1',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Also create sibling child
      await repo.saveNote(Note(
        id: 'c2',
        parentId: 'r1',
        title: 'Child 2',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Verify setup
      expect((await repo.getAllNotes()).length, equals(5));

      // Delete Child 1: should delete c1, gc1, and ggc1, and remove c1 from r1.childrenIds
      await repo.deleteNote('c1');

      expect(await repo.getNote('c1'), isNull);
      expect(await repo.getNote('gc1'), isNull);
      expect(await repo.getNote('ggc1'), isNull);

      // Root and Child 2 must remain
      final root = await repo.getNote('r1');
      expect(root, isNotNull);
      expect(root!.childrenIds, equals(['c2']));
      expect(await repo.getNote('c2'), isNotNull);

      // Now delete Root: should delete r1 and c2
      await repo.deleteNote('r1');
      expect((await repo.getAllNotes()).isEmpty, isTrue);
    });
  });

  group('UI Navigation & Hierarchy Flow Tests', () {
    testWidgets('Empty state, create root note, navigate to detail, and create subpage', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

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

      // 1. Verify calm empty state
      expect(find.text('All thoughts start here.'), findsOneWidget);
      expect(find.text('Create a note to begin.'), findsOneWidget);

      // 2. Tap "New note" to open full-screen note page directly
      await tester.tap(find.text('New note').first);
      await tester.pumpAndSettle();

      expect(find.byType(NoteDetailScreen), findsOneWidget);

      // Fill in note title and body
      await tester.enterText(find.byType(TextField).at(0), 'Business');
      await tester.enterText(find.byType(TextField).at(1), 'Reflections on strategy');
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      // Back to NotesScreen
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // 3. Verify note appears in Notes list
      expect(find.text('Business'), findsOneWidget);

      // 4. Tap note to open NoteDetailScreen
      await tester.tap(find.text('Business'));
      await tester.pumpAndSettle();

      expect(find.text('Reflections on strategy'), findsOneWidget);
      expect(find.text('Add page'), findsOneWidget);

      // 5. Tap "Add page" to create child note directly as full-screen page
      await tester.tap(find.text('Add page'));
      await tester.pumpAndSettle();

      expect(find.byType(NoteDetailScreen), findsOneWidget);
      // Breadcrumb displays parent 'Business'
      expect(find.text('Business'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Smart Q Estates');
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      // 6. Navigate back up to parent
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // Back on Business note
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Smart Q Estates'), findsOneWidget);

      // Navigate back to Notes list
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      expect(find.text('NOTES'), findsOneWidget);
      expect(find.text('1 page'), findsOneWidget); // Page count indicator
    });

    testWidgets('Safe subtree deletion with confirmation dialog', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      final parent = Note(
        id: 'p_1',
        title: 'Project Architecture',
        content: 'System specs',
        childrenIds: ['c_1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final child = Note(
        id: 'c_1',
        parentId: 'p_1',
        title: 'Database Schema',
        content: 'Tables and models',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(parent);
      await noteRepo.saveNote(child);

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

      // Open parent note
      await tester.tap(find.text('Project Architecture'));
      await tester.pumpAndSettle();

      // Tap delete icon
      await tester.tap(find.byTooltip('Delete note'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog warns about subpages
      expect(find.text('Delete Note'), findsOneWidget);
      expect(find.textContaining('This note has 1 subpage'), findsOneWidget);

      // Tap Cancel: verify nothing deleted
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Project Architecture'), findsOneWidget);

      // Tap delete again and confirm
      await tester.tap(find.byTooltip('Delete note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Popped back to NotesScreen: calm empty state
      expect(find.text('All thoughts start here.'), findsOneWidget);
      expect(await noteRepo.getAllNotes(), isEmpty);
    });

    testWidgets('Home displays real recent notes from repository', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      await noteRepo.saveNote(Note(
        id: 'n1',
        title: 'Recent Thought A',
        subtitle: 'Updated today',
        content: 'Note A content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

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

      expect(find.text('NOTES'), findsOneWidget);
      expect(find.text('Recent Thought A'), findsNWidgets(2)); // square card + recent notes item
    });
  });

  group('Mobile Viewport Overflow Verification', () {
    final viewports = <String, Size>{
      'iPhone SE (375x667)': const Size(375, 667),
      'iPhone Standard (390x844)': const Size(390, 844),
      'iPhone Pro Max (430x932)': const Size(430, 932),
      'Android Compact (360x800)': const Size(360, 800),
    };

    for (final entry in viewports.entries) {
      testWidgets('Verify no layout overflow on ${entry.key} for Notes & Detail screens', (WidgetTester tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final storage = InMemoryStorage();
        final noteRepo = LocalNoteRepository(storage: storage);
        final reviewRepo = LocalReviewRepository(storage: storage);

        final sampleNote = Note(
          id: 'view_test_note',
          title: 'Comprehensive Review of Distributed Systems and Autonomous Agents',
          subtitle: 'Architecture patterns for state replication and eventual consistency across clusters',
          content: 'A detailed exploration of raft consensus, vector clocks, and conflict-free replicated data types.',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await noteRepo.saveNote(sampleNote);

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

        // Check NotesScreen for overflow
        expect(tester.takeException(), isNull);
        expect(find.text('NOTES'), findsOneWidget);

        // Open NoteDetailScreen
        await tester.tap(find.textContaining('Comprehensive Review'));
        await tester.pumpAndSettle();

        // Check NoteDetailScreen for overflow
        expect(tester.takeException(), isNull);
        expect(find.text('Add page'), findsOneWidget);
      });
    }
  });
}
