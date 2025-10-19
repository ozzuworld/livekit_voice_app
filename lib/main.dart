import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiveKit Voice App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: VoiceCallPage(),
    );
  }
}

class VoiceCallPage extends StatefulWidget {
  @override
  _VoiceCallPageState createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  Room? room;
  bool isConnected = false;
  bool isMuted = true;
  bool isConnecting = false;
  List<RemoteParticipant> remoteParticipants = [];
  String statusMessage = 'Not Connected';
  
  final String websocketUrl = 'wss://livekit.ozzu.world';
  final String tokenUrl = 'https://api.ozzu.world/livekit/token';
  
  // Defaults (can be moved to settings later)
  final String defaultRoomName = 'voice-room';
  String get defaultParticipantName => 'flutter-user-${DateTime.now().millisecondsSinceEpoch}';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LiveKit Voice Call'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 4,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      isConnected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 48,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                    SizedBox(height: 10),
                    Text(
                      statusMessage,
                      style: TextStyle(
                        fontSize: 18,
                        color: isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Remote Participants: ${remoteParticipants.length}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (isConnected || isConnecting) ? null : connectToRoom,
                    icon: isConnecting 
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.phone),
                    label: Text(isConnecting ? 'Connecting...' : 'Connect'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isConnected ? disconnectFromRoom : null,
                    icon: Icon(Icons.phone_disabled),
                    label: Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isConnected ? toggleMute : null,
                icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
                label: Text(isMuted ? 'Unmute Microphone' : 'Mute Microphone'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isMuted ? Colors.orange : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 40),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Server Configuration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('WebSocket: $websocketUrl'),
                    Text('Token API: $tokenUrl'),
                    Text('roomName: $defaultRoomName'),
                    Text('participantName: ${defaultParticipantName.substring(0, 22)}...'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<String> getToken() async {
    try {
      setState(() { statusMessage = 'Getting authentication token...'; });
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          // Match June backend contract
          'roomName': defaultRoomName,
          'participantName': defaultParticipantName,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is String) return data;
        if (data is Map<String, dynamic>) {
          if (data['token'] != null) return data['token'];
          if (data['accessToken'] != null) return data['accessToken'];
          if (data['access_token'] != null) return data['access_token'];
          if (data['jwt'] != null) return data['jwt'];
          throw Exception('Token field not found in response. Available fields: ${data.keys.toList()}');
        }
        throw Exception('Unexpected token response format');
      } else {
        print('Token request failed - Status: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('Response headers: ${response.headers}');
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error getting token: $e');
      throw Exception('Could not get token: $e');
    }
  }

  Future<void> connectToRoom() async {
    setState(() { isConnecting = true; statusMessage = 'Initializing connection...'; });
    try {
      final token = await getToken();
      setState(() { statusMessage = 'Connecting to LiveKit server...'; });
      room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
      room!.addListener(_onRoomUpdate);
      await room!.connect(websocketUrl, token);
      await room!.localParticipant?.setMicrophoneEnabled(false);
      setState(() { isConnected = true; isConnecting = false; statusMessage = 'Connected to LiveKit room'; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully connected to voice room'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
      }
    } catch (error) {
      setState(() { isConnected = false; isConnecting = false; statusMessage = 'Connection failed'; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to connect: ${error.toString()}'), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
      }
    }
  }

  Future<void> disconnectFromRoom() async {
    try {
      setState(() { statusMessage = 'Disconnecting...'; });
      await room?.disconnect();
      room?.removeListener(_onRoomUpdate);
      setState(() { isConnected = false; remoteParticipants.clear(); isMuted = true; statusMessage = 'Disconnected'; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disconnected from voice room'), backgroundColor: Colors.grey, duration: Duration(seconds: 2)));
      }
    } catch (error) {
      setState(() { statusMessage = 'Error during disconnect'; });
    }
  }

  Future<void> toggleMute() async {
    try {
      if (room?.localParticipant != null) {
        await room!.localParticipant!.setMicrophoneEnabled(isMuted);
        setState(() { isMuted = !isMuted; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isMuted ? 'Microphone muted' : 'Microphone unmuted'), duration: Duration(seconds: 1)));
        }
      }
    } catch (error) {
      // ignore
    }
  }

  void _onRoomUpdate() {
    if (mounted) {
      setState(() { remoteParticipants = room?.remoteParticipants.values.toList() ?? []; });
    }
  }

  @override
  void dispose() {
    disconnectFromRoom();
    super.dispose();
  }
}
