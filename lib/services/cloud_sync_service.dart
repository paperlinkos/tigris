import 'package:flutter/foundation.dart';

enum SyncState {
  signedOut,
  savedLocally,
  syncing,
  synced,
  offline,
  error,
  accountMismatch,
}

class CloudSyncService extends ChangeNotifier {
  SyncState _state = SyncState.savedLocally;
  DateTime? _lastSyncedAt;
  String? _errorMessage;

  SyncState get state => _state;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get errorMessage => _errorMessage;

  void setSyncing() {
    _state = SyncState.syncing;
    _errorMessage = null;
    notifyListeners();
  }

  void setSignedOut() {
    _state = SyncState.signedOut;
    _errorMessage = null;
    notifyListeners();
  }

  void setAccountMismatch() {
    _state = SyncState.accountMismatch;
    _errorMessage = null;
    notifyListeners();
  }

  void setSynced() {
    _state = SyncState.synced;
    _lastSyncedAt = DateTime.now();
    _errorMessage = null;
    notifyListeners();
  }

  void setSavedLocally() {
    _state = SyncState.savedLocally;
    notifyListeners();
  }

  void setOffline() {
    _state = SyncState.offline;
    notifyListeners();
  }

  void setError(String error) {
    _state = SyncState.error;
    _errorMessage = error;
    notifyListeners();
  }
}
