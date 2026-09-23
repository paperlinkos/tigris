import 'package:flutter/material.dart';
import '../app/theme/app_typography.dart';
import '../app/theme/context_theme_extensions.dart';
import '../services/auth_service.dart';
import '../widgets/brand/tigris_logo.dart';

class LoginScreen extends StatefulWidget {
  final AuthService? authService;
  final VoidCallback? onLoginSuccess;

  const LoginScreen({
    super.key,
    this.authService,
    this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _finishAuth() {
    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = widget.authService ?? AuthService();
      final userCred = await auth.signInWithGoogle();
      if (userCred != null && mounted) {
        _finishAuth();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _mapAuthErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthErrorMessage(dynamic e) {
    final str = e.toString();
    if (str.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase Authentication is not activated yet in your Firebase Console. Go to console.firebase.google.com -> tigris-notes-app -> Authentication and click "Get started", then enable Email & Google.';
    }
    if (str.contains('Api10') || str.contains('DEVELOPER_ERROR')) {
      return 'Google Sign-In: Android SHA-1 fingerprint needs to be added in Firebase Console (Project Settings -> Add Fingerprint).';
    }
    if (str.contains('network-request-failed')) {
      return 'Network connection error. Check your internet connection.';
    }
    if (str.contains('email-already-in-use')) {
      return 'This email is already in use. Please sign in instead.';
    }
    if (str.contains('wrong-password') || str.contains('user-not-found') || str.contains('invalid-credential')) {
      return 'Invalid email or password.';
    }
    if (str.contains('weak-password')) {
      return 'Password is too weak. Must be at least 6 characters.';
    }
    if (str.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    return str.replaceFirst("Exception: ", "").trim();
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = widget.authService ?? AuthService();
      if (_isSignUp) {
        await auth.signUpWithEmail(email, password);
      } else {
        await auth.signInWithEmail(email, password);
      }
      if (mounted) {
        _finishAuth();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _mapAuthErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuestSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = widget.authService ?? AuthService();
      await auth.signInAnonymously();
      if (mounted) {
        _finishAuth();
      }
    } catch (_) {
      if (mounted) {
        _finishAuth(); // Graceful offline guest entry fallback
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Logo Header
                const Center(
                  child: TigrisLogo(
                    size: 56.0,
                    showWordmark: true,
                  ),
                ),
                const SizedBox(height: 12.0),
                Text(
                  'Your calm, offline-first personal learning space',
                  textAlign: TextAlign.center,
                  style: AppTypography.subtitle(
                    fontSize: 14.0,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 36.0),

                // Google Sign In Button
                OutlinedButton(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    side: BorderSide(color: context.appBorder, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    backgroundColor: context.appSurface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.g_mobiledata_rounded, size: 28.0, color: Color(0xFF4285F4)),
                      const SizedBox(width: 8.0),
                      Text(
                        'Continue with Google',
                        style: AppTypography.uiHeadline(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20.0),

                // Divider Or
                Row(
                  children: [
                    Expanded(child: Divider(color: context.appBorderSubtle)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'OR',
                        style: AppTypography.uiLabel(
                          fontSize: 11.0,
                          color: context.appTextTertiary,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: context.appBorderSubtle)),
                  ],
                ),
                const SizedBox(height: 20.0),

                // Error Message Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTypography.body(fontSize: 13.0, color: Colors.red),
                    ),
                  ),
                ],

                // Email Input
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTypography.body(fontSize: 15.0, color: context.appTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(color: context.appTextSecondary),
                    filled: true,
                    fillColor: context.appSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide(color: context.appBorderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),

                // Password Input
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: AppTypography.body(fontSize: 15.0, color: context.appTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: context.appTextSecondary),
                    filled: true,
                    fillColor: context.appSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide(color: context.appBorderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),

                // Email Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailAuth,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    backgroundColor: context.appTextPrimary,
                    foregroundColor: context.appBg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20.0,
                          height: 20.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: context.appBg,
                          ),
                        )
                      : Text(
                          _isSignUp ? 'Create Account' : 'Sign In with Email',
                          style: AppTypography.uiHeadline(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w600,
                            color: context.appBg,
                          ),
                        ),
                ),
                const SizedBox(height: 12.0),

                // Toggle Sign In / Sign Up
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                      _errorMessage = null;
                    });
                  },
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign In'
                        : 'Don\'t have an account? Sign Up',
                    style: AppTypography.uiLabel(
                      fontSize: 13.5,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 28.0),
                Divider(color: context.appBorderSubtle),
                const SizedBox(height: 12.0),

                // Continue as Guest (100% Offline)
                TextButton(
                  onPressed: _isLoading ? null : _handleGuestSignIn,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue as Guest (Offline Mode)',
                        style: AppTypography.uiHeadline(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: context.appTextTertiary,
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      Icon(Icons.arrow_forward_rounded, size: 16.0, color: context.appTextTertiary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
