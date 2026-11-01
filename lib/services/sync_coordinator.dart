import 'dart:async';
import 'cloud_sync_service.dart';

class SyncCoordinator {
  final Stream<String?> authChanges;
  final Stream<bool> connectivityChanges;
  final Future<void> Function(String uid) runSync;
  final CloudSyncService status;
  final Duration editDebounce;
  final Duration periodic;
  StreamSubscription<String?>? _authSub;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _debounce;
  Timer? _periodicTimer;
  String? _uid;
  bool _online = true;
  bool _started = false;

  SyncCoordinator({
    required this.authChanges,
    required this.connectivityChanges,
    required this.runSync,
    required this.status,
    this.editDebounce = const Duration(seconds: 2),
    this.periodic = const Duration(minutes: 5),
  });

  void start() {
    if (_started) return;
    _started = true;
    _authSub = authChanges.listen((uid) {
      _uid = uid;
      if (uid == null) {
        status.setSignedOut();
      } else {
        unawaited(syncNow());
      }
    });
    _connectivitySub = connectivityChanges.listen((online) {
      final wasOffline = !_online;
      _online = online;
      if (!online) {
        if (_uid != null) status.setOffline();
      } else if (wasOffline) {
        unawaited(syncNow());
      }
    }, onError: (Object _) {});
    _periodicTimer = Timer.periodic(periodic, (_) => unawaited(syncNow()));
  }

  void requestSoon() {
    _debounce?.cancel();
    _debounce = Timer(editDebounce, () => unawaited(syncNow()));
  }

  Future<void> syncNow() async {
    final uid = _uid;
    if (uid == null) {
      status.setSignedOut();
      return;
    }
    if (!_online) {
      status.setOffline();
      return;
    }
    await runSync(uid);
  }

  void onAppResumed() => unawaited(syncNow());

  void dispose() {
    _debounce?.cancel();
    _periodicTimer?.cancel();
    _authSub?.cancel();
    _connectivitySub?.cancel();
  }
}
