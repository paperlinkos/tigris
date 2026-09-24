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
import 'package:tigris/screens/notes_screen.dart';
import 'package:tigris/screens/note_detail_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 13 — Deep Hierarchy, Breadcrumbs, & Back Navigation Tests', () {
    testWidgets('1-9: Navigate Root -> Child -> Grandchild -> Deep note, verify breadcrumbs and logical back',
        (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      // Seed hierarchy: Business -> Smart Q Estates -> Service Apartments -> Market Research
      final business = Note(
        id: 'n_biz',
        title: 'Business',
        content: 'Core business strategies',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(business);

      final smartQ = Note(
        id: 'n_smartq',
        parentId: 'n_biz',
        title: 'Smart Q Estates',
        content: 'Real estate technology',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(smartQ);

      final serviceApts = Note(
        id: 'n_service_apts',
        parentId: 'n_smartq',
        title: 'Service Apartments',
        content: 'Short-term accommodation units',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(serviceApts);

      final marketResearch = Note(
        id: 'n_market_research',
        parentId: 'n_service_apts',
        title: 'Market Research',
        subtitle: 'Competitor pricing and demographics',
        content: 'Detailed analysis of local demand and pricing models.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(marketResearch);

      // Launch NotesScreen
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

      // 1. Open Root note: Business
      expect(find.text('Business'), findsOneWidget);
      await tester.tap(find.text('Business'));
      await tester.pumpAndSettle();

      // In root note: Business is the title, no ancestor breadcrumb
      expect(find.byType(NoteDetailScreen), findsOneWidget);
      expect(find.text('Smart Q Estates'), findsOneWidget); // In child notes list

      // 2. Open Child note: Smart Q Estates
      await tester.tap(find.text('Smart Q Estates'));
      await tester.pumpAndSettle();

      // Breadcrumb should show "Business"
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Service Apartments'), findsOneWidget); // In child notes list

      // 3. Open Grandchild: Service Apartments
      await tester.tap(find.text('Service Apartments'));
      await tester.pumpAndSettle();

      // Breadcrumbs: "Business / Smart Q Estates"
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Smart Q Estates'), findsOneWidget);
      expect(find.text('Market Research'), findsOneWidget); // In child notes list

      // 4. Open Deeply nested note: Market Research
      await tester.tap(find.text('Market Research'));
      await tester.pumpAndSettle();

      // 5. Verify Breadcrumbs: "Business / Smart Q Estates / Service Apartments"
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Smart Q Estates'), findsOneWidget);
      expect(find.text('Service Apartments'), findsOneWidget);

      // Verify page title is Market Research and is displayed separately
      final titleField = tester.widget<TextField>(find.byType(TextField).first);
      expect(titleField.controller?.text, equals('Market Research'));

      // 6-7. Tap an earlier breadcrumb: "Smart Q Estates"
      await tester.tap(find.text('Smart Q Estates'));
      await tester.pumpAndSettle();

      // We should be back at Smart Q Estates
      final smartQTitleField = tester.widget<TextField>(find.byType(TextField).first);
      expect(smartQTitleField.controller?.text, equals('Smart Q Estates'));

      // 8-9. Press Back: should return to previous logical location (Business)
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      final bizTitleField = tester.widget<TextField>(find.byType(TextField).first);
      expect(bizTitleField.controller?.text, equals('Business'));

      // Press Back from Business: returns to NotesScreen
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      expect(find.text('NOTES'), findsOneWidget);
    });

    testWidgets('10-13: Create child note and persist across app restart', (WidgetTester tester) async {
      final storage = PreferencesStorage();
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

      // 10. Create root note using full-screen route
      await tester.tap(find.text('New note').first);
      await tester.pumpAndSettle();

      expect(find.byType(NoteDetailScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Venture 2026');
      await tester.enterText(find.byType(TextField).at(1), 'Primary company agenda');
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      // 11. Create child note using + toolbar action
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create New Page Note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Q1 Deliverables');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      expect(find.text('Q1 Deliverables'), findsOneWidget);

      await tester.tap(find.text('Q1 Deliverables'));
      await tester.pumpAndSettle();

      // Verify child opened as a full-screen note page (no bottom sheet)
      expect(find.byType(NoteDetailScreen), findsOneWidget);
      expect(find.text('Venture 2026'), findsOneWidget); // In breadcrumbs

      await tester.enterText(find.byType(TextField).at(1), 'Key milestone deadlines');
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      // Navigate back to Venture 2026
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // Verify child appears in parent note
      expect(find.text('Q1 Deliverables'), findsOneWidget);

      // Navigate back to NotesScreen
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      expect(find.text('Venture 2026'), findsOneWidget);

      // 12-13. Reopen after simulated restart with fresh storage instance
      final storageRestarted = PreferencesStorage();
      final repoRestarted = LocalNoteRepository(storage: storageRestarted);

      final parentReloaded = await repoRestarted.getRootNotes();
      expect(parentReloaded.length, equals(1));
      expect(parentReloaded.first.title, equals('Venture 2026'));

      final childrenReloaded = await repoRestarted.getChildNotes(parentReloaded.first.id);
      expect(childrenReloaded.length, equals(1));
      expect(childrenReloaded.first.title, equals('Q1 Deliverables'));
      expect(childrenReloaded.first.parentId, equals(parentReloaded.first.id));
    });
  });

  group('Phase 13 — Viewport & Long Content Overflow Tests (360, 375, 390, 430)', () {
    final viewports = <String, Size>{
      'Android Compact (360x800)': const Size(360, 800),
      'iPhone SE (375x667)': const Size(375, 667),
      'iPhone Standard (390x844)': const Size(390, 844),
      'iPhone Pro Max (430x932)': const Size(430, 932),
    };

    for (final entry in viewports.entries) {
      testWidgets('14-18: Verify deep breadcrumbs, long titles, long content on ${entry.key}',
          (WidgetTester tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final storage = InMemoryStorage();
        final noteRepo = LocalNoteRepository(storage: storage);
        final reviewRepo = LocalReviewRepository(storage: storage);

        // Build 5-level deep hierarchy with long titles
        final n1 = Note(
          id: 'lvl1',
          title: 'International Consortium of Advanced Computing and AI Systems',
          content: 'Level 1 overview',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final n2 = Note(
          id: 'lvl2',
          parentId: 'lvl1',
          title: 'Distributed System State Coordination and High-Availability Architecture',
          content: 'Level 2 overview',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final n3 = Note(
          id: 'lvl3',
          parentId: 'lvl2',
          title: 'Consensus Protocols and Conflict-Free Replicated Data Formats',
          content: 'Level 3 overview',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final n4 = Note(
          id: 'lvl4',
          parentId: 'lvl3',
          title: 'Formal Safety Verification and Byzantine Fault Tolerance at Scale',
          subtitle: 'Mathematical proofs and automated state-space exploration methods',
          content:
              'In this section we provide mathematical bounds for state machine replication ' * 8,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await noteRepo.saveNote(n1);
        await noteRepo.saveNote(n2);
        await noteRepo.saveNote(n3);
        await noteRepo.saveNote(n4);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: RepositoryScope(
              noteRepository: noteRepo,
              reviewRepository: reviewRepo,
              child: NoteDetailScreen(
                noteId: n4.id,
                initialNote: n4,
                noteRepository: noteRepo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify no overflow occurred
        expect(tester.takeException(), isNull);

        // Verify breadcrumbs are rendered
        expect(find.text('Consensus Protocols and Conflict-Free Replicated Data Formats'), findsOneWidget);

        // Test breadcrumb horizontal scrollability
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(-100, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
