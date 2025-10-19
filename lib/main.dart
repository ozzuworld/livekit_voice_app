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
  
  // Your LiveKit server configuration
  final String websocketUrl = 'wss://livekit.ozzu.world';
  final String tokenUrl = 'https://api.ozzu.world/livekit/token';
  
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
            // Status Card
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
            
            // Connection Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Connect Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (isConnected || isConnecting) ? null : connectToRoom,
                    icon: isConnecting 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
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
                
                // Disconnect Button
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
            
            // Mute/Unmute Button
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
            
            // Info Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Configuration:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('WebSocket: $websocketUrl'),
                    Text('Token API: $tokenUrl'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Get token from your server
  Future<String> getToken() async {
    try {
      setState(() {
        statusMessage = 'Getting authentication token...';
      });
      
      final response = await http.get(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Adjust the key based on your server response format
        // Common formats: data['token'] or data['accessToken'] or data
        if (data is String) {
          return data; // If the response is directly the token
        } else if (data['token'] != null) {
          return data['token'];
        } else if (data['accessToken'] != null) {
          return data['accessToken'];
        } else {
          throw Exception('Token not found in response');
        }
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error getting token: $e');
      throw Exception('Could not get token: $e');
    }
  }
  
  // Connect to LiveKit room
  Future<void> connectToRoom() async {
    setState(() {
      isConnecting = true;
      statusMessage = 'Initializing connection...';
    });
    
    try {
      // Get token from your server
      final token = await getToken();
      
      setState(() {
        statusMessage = 'Connecting to LiveKit server...';
      });
      
      // Create room with options
      room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      
      // Set up event listeners
      room!.addListener(_onRoomUpdate);
      
      // Connect to the room
      await room!.connect(websocketUrl, token);
      
      // Enable microphone (start with muted)
      await room!.localParticipant?.setMicrophoneEnabled(false);
      
      setState(() {
        isConnected = true;
        isConnecting = false;
        statusMessage = 'Connected to LiveKit room';
      });
      
      print('Successfully connected to LiveKit room');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully connected to voice room'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (error) {
      print('Failed to connect to room: $error');
      setState(() {
        isConnected = false;
        isConnecting = false;
        statusMessage = 'Connection failed';
      });
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  // Disconnect from room
  Future<void> disconnectFromRoom() async {
    try {
      setState(() {
        statusMessage = 'Disconnecting...';
      });
      
      await room?.disconnect();
      room?.removeListener(_onRoomUpdate);
      
      setState(() {
        isConnected = false;
        remoteParticipants.clear();
        isMuted = true;
        statusMessage = 'Disconnected';
      });
      
      print('Disconnected from room');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected from voice room'),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      print('Error disconnecting: $error');
      setState(() {
        statusMessage = 'Error during disconnect';
      });
    }
  }
  
  // Toggle microphone mute/unmute
  Future<void> toggleMute() async {
    try {
      if (room?.localParticipant != null) {
        await room!.localParticipant!.setMicrophoneEnabled(isMuted);
        setState(() {
          isMuted = !isMuted;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMuted ? 'Microphone muted' : 'Microphone unmuted'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (error) {
      print('Error toggling mute: $error');
    }
  }
  
  // Handle room events
  void _onRoomUpdate() {
    if (mounted) {
      setState(() {
        remoteParticipants = room?.remoteParticipants.values.toList() ?? [];
      });
    }
  }
  
  @override
  void dispose() {
    disconnectFromRoom();
    super.dispose();
  }
}