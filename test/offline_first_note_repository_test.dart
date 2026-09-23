import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/offline_first_note_repository.dart';
import 'package:tigris/services/cloud_sync_service.dart';

void main() {
  group('OfflineFirstNoteRepository Tests', () {
    late InMemoryStorage storage;
    late LocalNoteRepository localRepo;
    late CloudSyncService syncService;
    late OfflineFirstNoteRepository offlineRepo;

    setUp(() {
      storage = InMemoryStorage();
      localRepo = LocalNoteRepository(storage: storage);
      syncService = CloudSyncService();
      offlineRepo = OfflineFirstNoteRepository(
        localRepo: localRepo,
        firestoreRepo: null, // Null simulates offline / disconnected state
        syncService: syncService,
      );
    });

    test('Saves notes to local storage immediately with zero latency', () async {
      final note = Note(
        id: 'offline_1',
        title: 'Offline Note Title',
        content: 'This note stays on the phone first',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await offlineRepo.saveNote(note);

      final fetched = await offlineRepo.getNote('offline_1');
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Offline Note Title'));
      expect(fetched.content, equals('This note stays on the phone first'));
      expect(syncService.state, equals(SyncState.savedLocally));
    });

    test('Fetches root and recent notes instantly from local storage', () async {
      final note1 = Note(
        id: 'root_1',
        title: 'Local Root 1',
        content: 'Content 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final note2 = Note(
        id: 'root_2',
        title: 'Local Root 2',
        content: 'Content 2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await offlineRepo.saveNote(note1);
      await offlineRepo.saveNote(note2);

      final roots = await offlineRepo.getRootNotes();
      expect(roots.length, equals(2));

      final recents = await offlineRepo.getRecentNotes(limit: 5);
      expect(recents.length, equals(2));
    });

    test('Deletes notes locally when offline', () async {
      final note = Note(
        id: 'del_1',
        title: 'To Delete',
        content: 'Delete test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await offlineRepo.saveNote(note);
      expect(await offlineRepo.getNote('del_1'), isNotNull);

      await offlineRepo.deleteNote('del_1');
      expect(await offlineRepo.getNote('del_1'), isNull);
    });
  });
}
