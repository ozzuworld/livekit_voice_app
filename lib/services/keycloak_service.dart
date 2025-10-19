import 'package:keycloak_wrapper/keycloak_wrapper.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Static config used across the app
  static const String frontendUrl = 'https://idp.ozzu.world';
  static const String realm = 'june-realm';
  static const String clientId = 'june-mobile-app';
  // Bundle identifier / applicationId of your app
  static const String bundleIdentifier = 'com.example.livekit_voice_app';

  final KeycloakWrapper _kc = KeycloakWrapper();

  late final KeycloakConfig _config;
  bool _initialized = false;
  bool _authenticated = false;
  Map<String, dynamic>? _userInfo;

  // Getters
  bool get isInitialized => _initialized;
  bool get isAuthenticated => _authenticated;
  Map<String, dynamic>? get userInfo => _userInfo;
  String get displayName {
    if (_userInfo != null) {
      return (_userInfo!['name'] ??
              _userInfo!['preferred_username'] ??
              _userInfo!['given_name'] ??
              'User').toString();
    }
    return 'User';
  }
  String get userEmail => (_userInfo?['email'] ?? 'No email').toString();

  Future<void> initialize() async {
    if (_initialized) return;

    _config = KeycloakConfig(
      bundleIdentifier: bundleIdentifier,
      clientId: clientId,
      frontendUrl: frontendUrl,
      realm: realm,
    );

    // In 0.4.23, initialize() may be a no-op; rely on auth stream
    _kc.authenticationStream.listen((isAuthed) async {
      _authenticated = isAuthed;
      if (isAuthed) {
        try {
          _userInfo = await _kc.getUserInfo();
        } catch (_) {
          _userInfo = null;
        }
      } else {
        _userInfo = null;
      }
    });

    _initialized = true;
  }

  Future<bool> login() async {
    // 0.4.23 expects the config as a positional argument
    final success = await _kc.login(_config);
    if (success) {
      try {
        _userInfo = await _kc.getUserInfo();
        _authenticated = true;
      } catch (_) {
        _userInfo = null;
      }
    }
    return success;
  }

  Future<void> logout() async {
    try {
      await _kc.logout();
    } finally {
      _authenticated = false;
      _userInfo = null;
    }
  }

  Future<String?> getAccessToken() async {
    // keycloak_wrapper 0.4.23 doesn't expose raw tokens; return null for now
    return null;
  }
}
