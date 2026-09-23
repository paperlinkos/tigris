import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/services/auth_service.dart';

void main() {
  group('AuthService Unit & Contract Tests', () {
    test('Default currentUserId returns guest_user when unauthenticated', () {
      final auth = AuthService();
      expect(auth.currentUserId, equals('guest_user'));
      expect(auth.isAuthenticated, isFalse);
      expect(auth.hasPasswordProvider, isFalse);
      expect(auth.hasGoogleProvider, isFalse);
    });

    test('setOrUpdatePassword throws when no user is signed in', () async {
      final auth = AuthService();
      expect(
        () => auth.setOrUpdatePassword('secret123'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
