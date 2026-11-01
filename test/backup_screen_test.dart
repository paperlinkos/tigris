import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/backup_store.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/screens/backup_screen.dart';
import 'package:tigris/services/backup_service.dart';
import 'package:tigris/services/drive_account.dart';

class _FakeAccount extends DriveAccount {
  bool connected;
  Object? connectError;
  _FakeAccount({this.connected = false});

  @override
  String? get email => connected ? 'writer@example.com' : null;
  @override
  Future<bool> connectSilently() async => connected;
  @override
  Future<bool> connect() async {
    if (connectError != null) throw connectError!;
    return connected = true;
  }

  @override
  Future<void> disconnect() async => connected = false;
}

class _FakeStore implements BackupStore {
  final files = <BackupFile>[];
  final data = <String, String>{};
  Object? listError;

  @override
  Future<List<BackupFile>> listBackups() async {
    if (listError != null) throw listError!;
    return files.reversed.toList();
  }

  @override
  Future<BackupFile> upload({required String baseName, required String json, required String readable}) async {
    final file = BackupFile(id: 'f${files.length}', name: '$baseName.json', createdAt: DateTime(2026, 3, 5, 14, 7));
    files.add(file);
    data[file.id] = json;
    return file;
  }

  @override
  Future<String> download(BackupFile file) async => data[file.id]!;
  @override
  Future<void> delete(BackupFile file) async => files.remove(file);
}

void main() {
  late LocalNoteRepository local;
  late _FakeStore store;
  late BackupService service;

  setUp(() async {
    final storage = InMemoryStorage();
    local = LocalNoteRepository(storage: storage);
    store = _FakeStore();
    service = BackupService(notes: local, localRepo: local, storage: storage, store: store);
    final now = DateTime(2026);
    await local.saveNote(Note(id: 'one', title: 'One', content: 'One', createdAt: now, updatedAt: now));
  });

  Future<void> pump(WidgetTester tester, _FakeAccount account) async {
    await tester.pumpWidget(MaterialApp(home: BackupScreen(service: service, account: account)));
    await tester.pumpAndSettle();
  }

  testWidgets('offers to connect, then shows the backups', (tester) async {
    await pump(tester, _FakeAccount());
    expect(find.textContaining('only see the files it creates'), findsOneWidget);
    expect(find.text('Back up now'), findsNothing);

    await tester.tap(find.text('Connect Google Drive'));
    await tester.pumpAndSettle();

    expect(find.text('writer@example.com'), findsOneWidget);
    expect(find.text('No backups yet.'), findsOneWidget);
  });

  testWidgets('backing up confirms and lists the backup by date', (tester) async {
    await pump(tester, _FakeAccount(connected: true));

    await tester.tap(find.text('Back up now'));
    await tester.pumpAndSettle();

    expect(find.text('Backup saved.'), findsOneWidget);
    expect(find.text('5 Mar 2026, 14:07'), findsOneWidget);
  });

  testWidgets('with no notes it says so', (tester) async {
    await local.deleteNote('one');
    await pump(tester, _FakeAccount(connected: true));

    await tester.tap(find.text('Back up now'));
    await tester.pumpAndSettle();

    expect(find.text('There are no notes to back up yet.'), findsOneWidget);
  });

  testWidgets('restore waits for confirmation', (tester) async {
    final backup = (await service.backupNow())!;
    final later = DateTime(2027);
    await local.saveNote(Note(id: 'one', title: 'Changed', content: 'x', createdAt: later, updatedAt: later));
    await pump(tester, _FakeAccount(connected: true));

    await tester.tap(find.text('5 Mar 2026, 14:07'));
    await tester.pumpAndSettle();
    expect(find.text('Restore this backup?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((await local.getNote('one'))?.title, 'Changed');

    await tester.tap(find.text('5 Mar 2026, 14:07'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(find.text('Restored 1 notes.'), findsOneWidget);
    expect((await local.getNote('one'))?.title, 'One');
    expect(store.files.first, backup);
    expect(find.text('Saved automatically before a restore'), findsOneWidget);
  });

  testWidgets('a Drive refusal shows a readable message', (tester) async {
    store.listError = const BackupStoreException(403, '{"raw":"secret detail"}');
    await pump(tester, _FakeAccount(connected: true));

    expect(find.textContaining('Drive API is turned on'), findsOneWidget);
    expect(find.textContaining('secret detail'), findsNothing);
  });

  testWidgets('a sign-in setup problem says what is wrong', (tester) async {
    final account = _FakeAccount()..connectError = PlatformException(code: 'sign_in_failed', message: 'ApiException: 10');
    await pump(tester, account);

    await tester.tap(find.text('Connect Google Drive'));
    await tester.pumpAndSettle();

    expect(find.textContaining("isn't set up"), findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
  });
}
