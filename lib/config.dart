// LiveKit Configuration
class LiveKitConfig {
  // Your LiveKit server endpoints
  static const String websocketUrl = 'wss://livekit.ozzu.world';
  static const String tokenUrl = 'https://api.ozzu.world/livekit/token';
  
  // Room configuration
  static const String defaultRoomName = 'voice-room';
  
  // User configuration
  static const String defaultUserName = 'Flutter User';
  
  // Connection timeouts (in seconds)
  static const int connectionTimeout = 30;
  static const int tokenTimeout = 10;
  
  // Audio settings
  static const bool startMuted = true;
  static const bool adaptiveStream = true;
  static const bool dynacast = true;
}