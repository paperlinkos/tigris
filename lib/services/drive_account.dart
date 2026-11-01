import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../repositories/backup_store.dart';

class DriveAccount {
  final GoogleSignIn _signIn = GoogleSignIn(
    scopes: const ['https://www.googleapis.com/auth/drive.file'],
    serverClientId: '544154185532-pfa7necu0t1pje69bek0289p6rm6vt1r.apps.googleusercontent.com',
  );
  GoogleSignInAccount? _account;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String? get email => _account?.email;

  Future<bool> connect() async {
    _account = await _signIn.signIn();
    return _account != null;
  }

  Future<bool> connectSilently() async {
    try {
      _account = await _signIn.signInSilently();
      return _account != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    await _signIn.signOut();
    _account = null;
  }

  Future<Map<String, String>> authHeaders() async {
    final account = _account;
    if (account == null) throw BackupNotConnectedException();
    return account.authHeaders;
  }
}
