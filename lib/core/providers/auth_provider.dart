import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../services/auth_service.dart';

import '../database/database.dart';

// ─── Auth State ─────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated }

class AppAuthState {
  final AuthStatus status;
  final supa.User? user;
  final String? errorMessage;

  const AppAuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
  });

  AppAuthState copyWith({
    AuthStatus? status,
    supa.User? user,
    String? errorMessage,
  }) {
    return AppAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

// ─── Auth Notifier ──────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AppAuthState> {
  final AuthService _authService;
  StreamSubscription<supa.AuthState>? _sub;

  AuthNotifier(this._authService) : super(const AppAuthState()) {
    _init();
  }

  Future<void> _init() async {
    // Check current session
    final user = _authService.currentUser;
    if (user != null) {
      await AppDatabase.instance.initForUser(user.id);
      state = AppAuthState(status: AuthStatus.authenticated, user: user);
    } else {
      await AppDatabase.instance.closeAndReset();
      state = const AppAuthState(status: AuthStatus.unauthenticated);
    }

    // Listen for auth changes
    _sub = _authService.onAuthStateChange.listen((authState) async {
      final session = authState.session;
      if (session != null) {
        await AppDatabase.instance.initForUser(session.user.id);
        state = AppAuthState(
          status: AuthStatus.authenticated,
          user: session.user,
        );
      } else {
        await AppDatabase.instance.closeAndReset();
        state = const AppAuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  /// Sign up with email and password.
  Future<bool> signUp({required String email, required String password}) async {
    try {
      await _authService.signUp(email: email, password: password);
      return true;
    } on supa.AuthException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Something went wrong. Try again.');
      return false;
    }
  }

  /// Sign in with email and password.
  Future<bool> signIn({required String email, required String password}) async {
    try {
      await _authService.signIn(email: email, password: password);
      return true;
    } on supa.AuthException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Something went wrong. Try again.');
      return false;
    }
  }

  /// Sign in with Google.
  Future<bool> signInWithGoogle() async {
    try {
      await _authService.signInWithGoogle();
      return true;
    } on supa.AuthException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Google Sign-In failed. Try again.');
      return false;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await AppDatabase.instance.closeAndReset();
    await _authService.signOut();
    state = const AppAuthState(status: AuthStatus.unauthenticated);
  }

  /// Clear error message.
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ─── Provider ───────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  return AuthNotifier(AuthService.instance);
});
