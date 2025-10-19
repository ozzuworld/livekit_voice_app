import 'package:keycloak_wrapper/keycloak_wrapper.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Static config
  static const String frontendUrl = 'https://idp.ozzu.world';
  static const String realm = 'allsafe';
  static const String clientId = 'june-mobile-app';
  static const String bundleIdentifier = 'com.example.livekit_voice_app';

  // Create KeycloakWrapper instance with config
  late final KeycloakWrapper _kc;
  
  bool _initialized = false;
  Map<String, dynamic>? _userInfo;

  // Getters
  bool get isInitialized => _initialized;
  bool get isAuthenticated => _kc.isAuthenticated;
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

    // Create KeycloakConfig
    final config = KeycloakConfig(
      bundleIdentifier: bundleIdentifier,
      clientId: clientId,
      frontendUrl: frontendUrl,
      realm: realm,
    );

    // Initialize KeycloakWrapper with config
    _kc = KeycloakWrapper(config: config);
    
    // Set up error handling
    _kc.onError = (message, error, stackTrace) {
      print('❌ Keycloak Error: $message');
      if (error != null) print('Error details: $error');
      if (stackTrace != null) print('Stack trace: $stackTrace');
    };
    
    // Initialize the wrapper
    _kc.initialize();
    
    // Listen to authentication stream
    _kc.authenticationStream.listen((isAuthed) async {
      print('🔐 Authentication state changed: $isAuthed');
      if (isAuthed) {
        try {
          _userInfo = await _kc.getUserInfo();
          print('✅ User info loaded: ${_userInfo?['name']}');
        } catch (e) {
          print('⚠️ Failed to load user info: $e');
          _userInfo = null;
        }
      } else {
        _userInfo = null;
      }
    });

    _initialized = true;
    print('✅ AuthService initialized');
  }

  Future<bool> login() async {
    try {
      print('🔑 Attempting login...');
      final success = await _kc.login();
      
      if (success) {
        print('✅ Login successful');
        // Fetch user info after successful login
        try {
          _userInfo = await _kc.getUserInfo();
          print('✅ User info loaded: ${_userInfo?['name']}');
        } catch (e) {
          print('⚠️ Failed to load user info after login: $e');
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
    try {
      print('👋 Attempting logout...');
      await _kc.logout();
      _userInfo = null;
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
      // Clear local state even if logout fails
      _userInfo = null;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      return _kc.accessToken;
    } catch (e) {
      print('⚠️ Failed to get access token: $e');
      return null;
    }
  }
  
  String? get idToken => _kc.idToken;
  String? get refreshToken => _kc.refreshToken;
}