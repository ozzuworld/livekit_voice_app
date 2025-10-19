import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  KeycloakWrapper? _kc;
  final _secure = const FlutterSecureStorage();

  bool _initialized = false;
  bool _authenticated = false;
  Map<String, dynamic>? _userInfo;
  String? _accessToken;
  String? _refreshToken;

  // Configuration
  static const String keycloakUrl = 'https://idp.ozzu.world';
  static const String realm = 'june-realm';
  static const String clientId = 'june-mobile-app';
  static const String redirectUri = 'livekit://auth';

  // Getters
  bool get isInitialized => _initialized;
  bool get isAuthenticated => _authenticated;
  Map<String, dynamic>? get userInfo => _userInfo;
  String get displayName {
    if (_userInfo != null) {
      return _userInfo!['name'] ?? 
             _userInfo!['preferred_username'] ?? 
             _userInfo!['given_name'] ?? 
             'User';
    }
    return 'User';
  }
  
  String get userEmail {
    return _userInfo?['email'] ?? 'No email';
  }

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      print('🔐 Initializing Keycloak wrapper...');
      
      // Initialize KeycloakWrapper
      _kc = KeycloakWrapper();
      await _kc!.initialize(
        issuer: '$keycloakUrl/realms/$realm',
        clientId: clientId,
        redirectUrl: redirectUri,
        scopes: ['openid', 'profile', 'email'],
      );

      // Try to restore previous session
      _accessToken = await _secure.read(key: 'kc_access_token');
      _refreshToken = await _secure.read(key: 'kc_refresh_token');
      
      if (_accessToken != null && _refreshToken != null) {
        print('🔐 Found stored tokens, validating...');
        try {
          // Try to get user info with stored token
          _userInfo = await _kc!.getUserInfo();
          _authenticated = true;
          print('✅ Session restored successfully');
        } catch (e) {
          print('❌ Stored tokens invalid: $e');
          await _clearTokens();
        }
      }

      _initialized = true;
      print('✅ Keycloak service initialized');
    } catch (e) {
      print('❌ Keycloak initialization failed: $e');
      _initialized = true; // Set to avoid retry loops
      rethrow;
    }
  }

  Future<bool> login() async {
    if (!_initialized || _kc == null) {
      throw Exception('Keycloak service not initialized');
    }

    try {
      print('🔐 Starting login flow...');
      
      final result = await _kc!.login(
        issuer: '$keycloakUrl/realms/$realm',
        clientId: clientId,
        redirectUrl: redirectUri,
        scopes: ['openid', 'profile', 'email'],
      );
      
      if (result.isSuccess && result.data != null) {
        final tokens = result.data!;
        _accessToken = tokens.accessToken;
        _refreshToken = tokens.refreshToken;
        
        // Save tokens securely
        await _secure.write(key: 'kc_access_token', value: _accessToken!);
        await _secure.write(key: 'kc_refresh_token', value: _refreshToken!);
        
        // Get user info
        _userInfo = await _kc!.getUserInfo();
        _authenticated = true;
        
        print('✅ Login successful: ${displayName}');
        return true;
      } else {
        print('❌ Login failed: ${result.message}');
        return false;
      }
    } catch (e) {
      print('❌ Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    if (!_authenticated || _kc == null) return;

    try {
      print('🔐 Starting logout...');
      
      await _kc!.logout(
        issuer: '$keycloakUrl/realms/$realm',
        redirectUrl: redirectUri,
      );
      
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
    } finally {
      await _clearAuthentication();
    }
  }

  Future<String?> getAccessToken() async {
    if (!_authenticated || _accessToken == null) return null;
    
    try {
      // Try to refresh token if needed
      if (_refreshToken != null) {
        final result = await _kc!.refreshToken(
          issuer: '$keycloakUrl/realms/$realm',
          clientId: clientId,
          refreshToken: _refreshToken!,
        );
        
        if (result.isSuccess && result.data != null) {
          final tokens = result.data!;
          _accessToken = tokens.accessToken;
          _refreshToken = tokens.refreshToken;
          
          // Update stored tokens
          await _secure.write(key: 'kc_access_token', value: _accessToken!);
          await _secure.write(key: 'kc_refresh_token', value: _refreshToken!);
        }
      }
      
      return _accessToken;
    } catch (e) {
      print('❌ Token refresh failed: $e');
      return _accessToken; // Return existing token even if refresh failed
    }
  }

  Future<void> _clearTokens() async {
    await _secure.delete(key: 'kc_access_token');
    await _secure.delete(key: 'kc_refresh_token');
  }

  Future<void> _clearAuthentication() async {
    _authenticated = false;
    _userInfo = null;
    _accessToken = null;
    _refreshToken = null;
    await _clearTokens();
  }
}