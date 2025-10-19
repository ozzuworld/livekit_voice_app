import 'package:keycloak_wrapper/keycloak_wrapper.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Static config used across the app
  static const String frontendUrl = 'https://idp.ozzu.world';
  static const String realm = 'june-realm';
  static const String clientId = 'june-mobile-app';
  // Bundle identifier for your app (matches android/app/build.gradle applicationId)
  static const String bundleIdentifier = 'com.example.livekit_voice_app';

  late KeycloakWrapper _kc;

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
  String get userEmail {
    return (_userInfo?['email'] ?? 'No email').toString();
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      print('🔐 Initializing Keycloak wrapper...');
      
      // Create Keycloak configuration
      final config = KeycloakConfig(
        bundleIdentifier: bundleIdentifier,
        clientId: clientId,
        frontendUrl: frontendUrl,
        realm: realm,
      );
      
      _kc = KeycloakWrapper(config: config);
      
      // Initialize the wrapper
      await _kc.initialize();
      
      // Listen for authentication state changes
      _kc.authenticationStream.listen((isAuthenticated) async {
        print('🔐 Auth state changed: $isAuthenticated');
        _authenticated = isAuthenticated;
        
        if (isAuthenticated) {
          try {
            _userInfo = await _kc.getUserInfo();
            print('✅ User info loaded: ${displayName}');
          } catch (e) {
            print('❌ Failed to load user info: $e');
            _userInfo = null;
          }
        } else {
          _userInfo = null;
        }
      });

      _initialized = true;
      print('✅ Keycloak service initialized');
    } catch (e) {
      print('❌ Keycloak initialization failed: $e');
      _initialized = true; // Set to avoid retry loops
      rethrow;
    }
  }

  Future<bool> login() async {
    if (!_initialized) {
      throw Exception('Keycloak service not initialized');
    }

    try {
      print('🔐 Starting login flow...');
      
      final success = await _kc.login();
      
      if (success) {
        // Get user info after successful login
        try {
          _userInfo = await _kc.getUserInfo();
          _authenticated = true;
          print('✅ Login successful: ${displayName}');
        } catch (e) {
          print('❌ Failed to get user info after login: $e');
        }
      } else {
        print('❌ Login failed');
      }
      
      return success;
    } catch (e) {
      print('❌ Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    if (!_authenticated) return;

    try {
      print('🔐 Starting logout...');
      
      await _kc.logout();
      
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
    } finally {
      _authenticated = false;
      _userInfo = null;
    }
  }

  Future<String?> getAccessToken() async {
    // keycloak_wrapper 0.4.23 doesn't expose raw access tokens
    // For now, return null so the backend token endpoint works without Authorization header
    // This can be enhanced later if needed
    return null;
  }
}