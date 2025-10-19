import 'package:keycloak_flutter/keycloak_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  KeycloakService? _keycloakService;
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  KeycloakProfile? _userProfile;
  String? _accessToken;

  // Your Keycloak configuration from June backend
  static const String keycloakUrl = 'http://june-idp.june-services.svc.cluster.local:8080';
  static const String realm = 'june-realm';
  static const String clientId = 'june-orchestrator';
  
  // Public getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  KeycloakProfile? get userProfile => _userProfile;
  String? get accessToken => _accessToken;
  String get displayName => _userProfile?.firstName ?? _userProfile?.username ?? 'User';

  /// Initialize Keycloak service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🔐 Initializing Keycloak service...');
      
      _keycloakService = KeycloakService(
        KeycloakConfig(
          url: keycloakUrl,
          realm: realm,
          clientId: clientId,
        ),
      );

      // Initialize with check-sso to automatically login if session exists
      await _keycloakService!.init(
        initOptions: KeycloakInitOptions(
          onLoad: 'check-sso',
          checkLoginIframe: false, // Better for mobile
          silentCheckSsoRedirectUri: '/silent-check-sso.html',
        ),
      );

      // Set up authentication state
      await _updateAuthenticationState();
      
      // Listen for authentication events
      _keycloakService!.keycloakEventsStream.listen((event) {
        print('🔐 Keycloak event: ${event.type}');
        switch (event.type) {
          case KeycloakEventType.onAuthSuccess:
            _updateAuthenticationState();
            break;
          case KeycloakEventType.onAuthLogout:
            _clearAuthenticationState();
            break;
          case KeycloakEventType.onTokenExpired:
            _handleTokenExpired();
            break;
          default:
            break;
        }
      });

      _isInitialized = true;
      print('✅ Keycloak service initialized successfully');
      
    } catch (e) {
      print('❌ Failed to initialize Keycloak: $e');
      _isInitialized = true; // Set to true even on failure to prevent retry loops
      rethrow;
    }
  }

  /// Login user
  Future<bool> login() async {
    if (!_isInitialized || _keycloakService == null) {
      throw Exception('Keycloak service not initialized');
    }

    try {
      print('🔐 Starting login process...');
      
      await _keycloakService!.login(
        KeycloakLoginOptions(
          scope: 'openid profile email',
          redirectUri: 'livekit://auth', // Custom scheme for mobile
        ),
      );

      await _updateAuthenticationState();
      
      if (_isAuthenticated) {
        await _saveTokenToStorage();
        print('✅ Login successful');
        return true;
      } else {
        print('❌ Login failed - not authenticated after login attempt');
        return false;
      }
    } catch (e) {
      print('❌ Login error: $e');
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    if (!_isInitialized || _keycloakService == null) return;

    try {
      print('🔐 Starting logout process...');
      
      await _keycloakService!.logout(
        KeycloakLogoutOptions(
          redirectUri: 'livekit://auth',
        ),
      );
      
      await _clearAuthenticationState();
      await _clearTokenFromStorage();
      
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
      // Clear state anyway
      await _clearAuthenticationState();
      await _clearTokenFromStorage();
    }
  }

  /// Refresh access token if needed
  Future<bool> refreshTokenIfNeeded() async {
    if (!_isAuthenticated || _keycloakService == null) return false;

    try {
      // Refresh if token expires within 30 seconds
      final success = await _keycloakService!.updateToken(30);
      if (success) {
        await _updateAuthenticationState();
        await _saveTokenToStorage();
      }
      return success;
    } catch (e) {
      print('❌ Token refresh failed: $e');
      return false;
    }
  }

  /// Get access token for API calls
  Future<String?> getAccessToken() async {
    await refreshTokenIfNeeded();
    return _accessToken;
  }

  /// Update authentication state from Keycloak
  Future<void> _updateAuthenticationState() async {
    if (_keycloakService == null) return;

    try {
      _isAuthenticated = _keycloakService!.authenticated;
      
      if (_isAuthenticated) {
        _accessToken = _keycloakService!.token;
        _userProfile = await _keycloakService!.loadUserProfile();
        print('🔐 User authenticated: ${_userProfile?.username}');
      }
    } catch (e) {
      print('❌ Failed to update authentication state: $e');
      _isAuthenticated = false;
      _accessToken = null;
      _userProfile = null;
    }
  }

  /// Clear authentication state
  Future<void> _clearAuthenticationState() async {
    _isAuthenticated = false;
    _accessToken = null;
    _userProfile = null;
  }

  /// Handle token expiration
  void _handleTokenExpired() {
    print('🔐 Token expired, clearing authentication state');
    _clearAuthenticationState();
  }

  /// Save token to local storage
  Future<void> _saveTokenToStorage() async {
    if (_accessToken != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('keycloak_access_token', _accessToken!);
    }
  }

  /// Clear token from local storage
  Future<void> _clearTokenFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('keycloak_access_token');
  }
}