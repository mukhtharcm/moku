import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages PocketBase authentication with persistent token storage.
class AuthService {
  PocketBase? _pb;
  static const _authKey = 'pb_auth';

  PocketBase? get pb => _pb;
  bool get isAuthenticated => _pb?.authStore.isValid ?? false;
  String? get userId => _pb?.authStore.record?.id;

  /// Initialize PocketBase client with the given server URL.
  /// Restores any previously saved auth state.
  Future<void> init(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final savedAuth = prefs.getString(_authKey);

    _pb = PocketBase(
      serverUrl,
      authStore: AsyncAuthStore(
        save: (data) async {
          final p = await SharedPreferences.getInstance();
          await p.setString(_authKey, data);
        },
        initial: savedAuth,
      ),
    );
  }

  /// Login with email and password.
  Future<void> login(String email, String password) async {
    _ensureInitialized();
    await _pb!.collection('users').authWithPassword(email, password);
  }

  /// Register a new account, then auto-login.
  Future<void> register(String email, String password) async {
    _ensureInitialized();
    await _pb!.collection('users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
    });
    await login(email, password);
  }

  /// Refresh the current auth token.
  Future<void> refreshAuth() async {
    _ensureInitialized();
    if (_pb!.authStore.isValid) {
      await _pb!.collection('users').authRefresh();
    }
  }

  /// Logout and clear stored auth data.
  Future<void> logout() async {
    _pb?.authStore.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
  }

  /// Dispose the client.
  void dispose() {
    _pb = null;
  }

  void _ensureInitialized() {
    if (_pb == null) {
      throw StateError('AuthService not initialized. Call init() first.');
    }
  }
}
