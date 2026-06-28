import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthState {
  final bool isLoggedIn;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? idToken;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.email,
    this.displayName,
    this.photoUrl,
    this.idToken,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? email,
    String? displayName,
    String? photoUrl,
    String? idToken,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      idToken: idToken ?? this.idToken,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  AuthNotifier() : super(const AuthState()) {
    // Check if user is already signed in silently at startup
    _googleSignIn.signInSilently().then((account) {
      if (account != null) {
        _updateUser(account);
      }
    }).catchError((e) {
      // Fail silently on startup
    });
  }

  Future<void> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        await _updateUser(account);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _updateUser(GoogleSignInAccount account) async {
    final auth = await account.authentication;
    state = AuthState(
      isLoggedIn: true,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
      idToken: auth.idToken,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
