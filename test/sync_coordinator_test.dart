import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/services/cloud_sync_service.dart';
import 'package:tigris/services/sync_coordinator.dart';

void main() {
  test('syncs on sign-in and does not sync while signed out', () async {
    final auth = StreamController<String?>();
    final connectivity = StreamController<bool>();
    var calls = 0;
    final coordinator = SyncCoordinator(
      authChanges: auth.stream,
      connectivityChanges: connectivity.stream,
      runSync: (_) async => calls++,
      status: CloudSyncService(),
      editDebounce: Duration.zero,
    );
    coordinator.start();
    auth.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 0);
    auth.add('uid');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    coordinator.dispose();
    await auth.close();
    await connectivity.close();
  });

  group('triggers', () {
    late StreamController<String?> auth;
    late StreamController<bool> connectivity;
    late CloudSyncService status;
    late SyncCoordinator coordinator;
    late int calls;

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

    setUp(() {
      auth = StreamController<String?>();
      connectivity = StreamController<bool>();
      status = CloudSyncService();
      calls = 0;
      coordinator = SyncCoordinator(
        authChanges: auth.stream,
        connectivityChanges: connectivity.stream,
        runSync: (_) async => calls++,
        status: status,
        editDebounce: const Duration(milliseconds: 20),
      )..start();
    });

    tearDown(() async {
      coordinator.dispose();
      await auth.close();
      await connectivity.close();
    });

    test('reconnecting syncs, including when the app opened offline', () async {
      connectivity.add(false);
      auth.add('uid');
      await settle();
      expect(calls, 0);
      expect(status.state, SyncState.offline);

      connectivity.add(true);
      await settle();
      expect(calls, 1);
    });

    test('many quick edits become one sync', () async {
      auth.add('uid');
      await settle();
      calls = 0;

      for (var i = 0; i < 5; i++) {
        coordinator.requestSoon();
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(calls, 1);
    });

    test('an edit while offline syncs on reconnect', () async {
      auth.add('uid');
      connectivity.add(false);
      await settle();
      calls = 0;

      coordinator.requestSoon();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(calls, 0);

      connectivity.add(true);
      await settle();
      expect(calls, 1);
    });

    test('resuming the app syncs', () async {
      auth.add('uid');
      await settle();
      calls = 0;

      coordinator.onAppResumed();
      await settle();
      expect(calls, 1);
    });

    test('signed out never syncs and never claims to be offline', () async {
      auth.add(null);
      connectivity.add(false);
      connectivity.add(true);
      await settle();
      coordinator.onAppResumed();
      await settle();

      expect(calls, 0);
      expect(status.state, SyncState.signedOut);
    });
  });
}
