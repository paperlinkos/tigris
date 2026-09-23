import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth? _auth;
  final GoogleSignIn? _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth,
        _googleSignIn = googleSignIn;

  FirebaseAuth? get _authInstance {
    if (_auth != null) return _auth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser {
    try {
      return _authInstance?.currentUser;
    } catch (_) {
      return null;
    }
  }

  String get currentUserId => currentUser?.uid ?? 'guest_user';

  bool get isAuthenticated => currentUser != null && !currentUser!.isAnonymous;

  bool get hasPasswordProvider {
    final user = currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  bool get hasGoogleProvider {
    final user = currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  Stream<User?> get authStateChanges {
    try {
      final inst = _authInstance;
      if (inst != null) return inst.authStateChanges();
    } catch (_) {}
    return Stream.value(null);
  }

  Future<void> setOrUpdatePassword(String newPassword) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in.');
    }
    final email = user.email;
    if (email == null || email.trim().isEmpty) {
      throw Exception('No email address associated with this account.');
    }
    if (newPassword.trim().length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    try {
      if (hasPasswordProvider) {
        await user.updatePassword(newPassword.trim());
      } else {
        final credential = EmailAuthProvider.credential(
          email: email.trim(),
          password: newPassword.trim(),
        );
        await user.linkWithCredential(credential);
      }
      await user.reload();
      notifyListeners();
    } catch (e) {
      debugPrint('Set Password Error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final gSignIn = _googleSignIn ??
          GoogleSignIn(
            serverClientId: '544154185532-pfa7necu0t1pje69bek0289p6rm6vt1r.apps.googleusercontent.com',
          );
      final googleUser = await gSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final inst = _authInstance;
      if (inst == null) return null;
      final userCredential = await inst.signInWithCredential(credential);
      notifyListeners();
      return userCredential;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final inst = _authInstance;
      if (inst == null) return null;
      final userCredential = await inst.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      notifyListeners();
      return userCredential;
    } catch (e) {
      debugPrint('Email Sign-In Error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final inst = _authInstance;
      if (inst == null) return null;
      final userCredential = await inst.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      notifyListeners();
      return userCredential;
    } catch (e) {
      debugPrint('Email Sign-Up Error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInAnonymously() async {
    try {
      final inst = _authInstance;
      if (inst == null) return null;
      final userCredential = await inst.signInAnonymously();
      notifyListeners();
      return userCredential;
    } catch (e) {
      debugPrint('Anonymous Auth Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      final gSignIn = _googleSignIn ?? GoogleSignIn();
      await gSignIn.signOut();
    } catch (_) {}
    try {
      await _authInstance?.signOut();
    } catch (_) {}
    notifyListeners();
  }
}
