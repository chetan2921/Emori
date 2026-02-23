import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase Auth for email/password and Google Sign-In.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;
  GoTrueClient get _auth => _client.auth;

  // ─── State ──────────────────────────────────────────────────────

  bool get isLoggedIn => _auth.currentUser != null;
  User? get currentUser => _auth.currentUser;
  Session? get currentSession => _auth.currentSession;

  /// Stream of auth state changes.
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  // ─── Email / Password ──────────────────────────────────────────

  /// Register a new user with email and password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _auth.signUp(email: email, password: password);
  }

  /// Sign in with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithPassword(email: email, password: password);
  }

  // ─── Google Sign-In ────────────────────────────────────────────

  /// Sign in with Google using native Google Sign-In flow.
  Future<AuthResponse> signInWithGoogle() async {
    const webClientId = 'YOUR_GOOGLE_WEB_CLIENT_ID'; // TODO: Replace
    const iosClientId = 'YOUR_GOOGLE_IOS_CLIENT_ID'; // TODO: Replace

    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: iosClientId,
      serverClientId: webClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('Google Sign-In was cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw AuthException('Failed to get Google ID token');
    }

    return await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  // ─── Sign Out ──────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
