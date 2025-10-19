import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  late final KeycloakWrapper _kc;
  final _secure = const FlutterSecureStorage();

  bool _initialized = false;
  bool _authenticated = false;
  OIDCUser? _user;
  String? _accessToken;
  String? _refreshToken;

  // Config
  static const _issuer = 'https://idp.ozzu.world/realms/june-realm';
  static const _clientId = 'june-mobile-app';
  static const _redirectUri = 'livekit://auth';
  static const _scopes = ['openid', 'profile', 'email'];

  bool get isInitialized => _initialized;
  bool get isAuthenticated => _authenticated;
  OIDCUser? get user => _user;
  String get displayName => _user?.name ?? _user?.preferredUsername ?? 'User';

  Future<void> initialize() async {
    if (_initialized) return;
    _kc = KeycloakWrapper(
      issuer: _issuer,
      clientId: _clientId,
      redirectUrl: _redirectUri,
      scopes: _scopes,
      usePkce: true,
    );

    // Try restore session
    _accessToken = await _secure.read(key: 'kc_access');
    _refreshToken = await _secure.read(key: 'kc_refresh');
    if (_accessToken != null) {
      try {
        _user = await _kc.getUserInfo(accessToken: _accessToken!);
        _authenticated = true;
      } catch (_) {
        _authenticated = false;
      }
    }

    _initialized = true;
  }

  Future<bool> login() async {
    final result = await _kc.login();
    if (result != null) {
      _accessToken = result.accessToken;
      _refreshToken = result.refreshToken;
      await _secure.write(key: 'kc_access', value: _accessToken);
      await _secure.write(key: 'kc_refresh', value: _refreshToken);
      _user = await _kc.getUserInfo(accessToken: _accessToken!);
      _authenticated = true;
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    try {
      if (_refreshToken != null) {
        await _kc.logout(refreshToken: _refreshToken!);
      }
    } finally {
      _authenticated = false;
      _user = null;
      _accessToken = null;
      _refreshToken = null;
      await _secure.delete(key: 'kc_access');
      await _secure.delete(key: 'kc_refresh');
    }
  }

  Future<bool> _refreshIfNeeded() async {
    if (_accessToken == null || _refreshToken == null) return false;
    final willExpire = await _kc.willAccessTokenExpireIn(_accessToken!, const Duration(seconds: 30));
    if (!willExpire) return true;
    try {
      final tokens = await _kc.refreshToken(refreshToken: _refreshToken!);
      _accessToken = tokens.accessToken;
      _refreshToken = tokens.refreshToken;
      await _secure.write(key: 'kc_access', value: _accessToken);
      await _secure.write(key: 'kc_refresh', value: _refreshToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    if (!_authenticated) return null;
    await _refreshIfNeeded();
    return _accessToken;
  }
}
