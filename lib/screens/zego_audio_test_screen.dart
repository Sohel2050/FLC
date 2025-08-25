import 'package:flutter/material.dart';
import 'package:flutter_chess_app/env.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class ZegoAudioTestScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const ZegoAudioTestScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ZegoAudioTestScreen> createState() => _ZegoAudioTestScreenState();
}

class _ZegoAudioTestScreenState extends State<ZegoAudioTestScreen> {
  // Audio room state variables
  bool _isInAudioRoom = false;
  bool _isMicrophoneEnabled = false;
  bool _isSpeakerMuted = false;
  bool _isZegoEngineInitialized = false;
  String? _currentAudioRoomId;

  // Test room configuration
  static const String TEST_ROOM_ID = 'test_audio_room_123';

  // Test users data
  final List<Map<String, String>> testUsers = [
    {'id': 'user_001', 'name': 'Dexter'},
    {'id': 'user_002', 'name': 'Bob'},
    {'id': 'user_003', 'name': 'Charlie'},
    {'id': 'user_004', 'name': 'Diana'},
  ];

  @override
  void initState() {
    super.initState();
    _logMessage(
      'ZegoAudioTestScreen initialized for user: ${widget.userName} (${widget.userId})',
    );
  }

  @override
  void dispose() {
    _logMessage('Disposing ZegoAudioTestScreen');
    if (_isInAudioRoom) {
      _cleanupZegoEngine().catchError((e) {
        _logMessage('Error during cleanup in dispose: $e');
      });
    }
    super.dispose();
  }

  void _logMessage(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    print('[$timestamp] ZegoAudioTest: $message');
  }

  Future<void> _initializeZegoEngine() async {
    if (_isZegoEngineInitialized) {
      _logMessage('Zego engine already initialized');
      return;
    }

    try {
      _logMessage('Initializing Zego Express Engine...');

      // Initialize Zego Express Engine
      await ZegoExpressEngine.createEngineWithProfile(
        ZegoEngineProfile(
          Env.zegoAppId,
          ZegoScenario.Default,
          appSign: Env.zegoAppSign,
        ),
      );

      _logMessage('Zego Express Engine created successfully');

      // Join room
      final userID = widget.userId;
      final userName = widget.userName;

      _logMessage(
        'Attempting to join room: $TEST_ROOM_ID as $userName ($userID)',
      );

      await ZegoExpressEngine.instance.loginRoom(
        TEST_ROOM_ID,
        ZegoUser(userID, userName),
      );

      _logMessage('Successfully joined room: $TEST_ROOM_ID');

      _isZegoEngineInitialized = true;
      _currentAudioRoomId = TEST_ROOM_ID;

      // Set up event listeners
      _setupZegoEventListeners();
    } catch (e) {
      _logMessage('Failed to initialize ZegoCloud engine: $e');
      rethrow;
    }
  }

  void _setupZegoEventListeners() {
    _logMessage('Setting up Zego event listeners');

    // Listen for room state changes
    ZegoExpressEngine.onRoomStateChanged = (
      String roomID,
      ZegoRoomStateChangedReason reason,
      int errorCode,
      Map<String, dynamic> extendedData,
    ) {
      _logMessage(
        'Room state changed - Room: $roomID, Reason: $reason, Error: $errorCode',
      );
    };

    // Listen for user state changes
    ZegoExpressEngine.onRoomUserUpdate = (
      String roomID,
      ZegoUpdateType updateType,
      List<ZegoUser> userList,
    ) {
      _logMessage(
        'Room user update - Room: $roomID, Type: $updateType, Users: ${userList.map((u) => u.userName).join(', ')}',
      );
    };

    // Listen for audio state changes
    // ZegoExpressEngine.onCapturedAudioFirstFrame = () {
    //   _logMessage('Audio capture started (first frame captured)');
    // };

    // ZegoExpressEngine.onRemoteAudioStateChanged = (String streamID, ZegoRemoteAudioState state, ZegoRemoteAudioStateChangedReason reason, String userID) {
    //   _logMessage('Remote audio state changed - Stream: $streamID, User: $userID, State: $state, Reason: $reason');
    // };
  }

  Future<void> _cleanupZegoEngine() async {
    try {
      _logMessage('Starting Zego engine cleanup...');

      if (_isZegoEngineInitialized && _currentAudioRoomId != null) {
        _logMessage('Logging out from room: $_currentAudioRoomId');
        await ZegoExpressEngine.instance.logoutRoom(_currentAudioRoomId!);

        _logMessage('Destroying Zego engine...');
        await ZegoExpressEngine.destroyEngine();

        _isZegoEngineInitialized = false;
        _currentAudioRoomId = null;

        _logMessage('Zego engine cleanup completed');
      }
    } catch (e) {
      _logMessage('Error during ZegoCloud cleanup: $e');
    }
  }

  Future<void> _joinAudioRoom() async {
    if (_isInAudioRoom) {
      _logMessage('Already in audio room');
      return;
    }

    try {
      _logMessage('Attempting to join audio room...');

      await _initializeZegoEngine();

      setState(() {
        _isInAudioRoom = true;
        _isMicrophoneEnabled = false; // Start with mic disabled
      });

      _logMessage('Successfully joined audio room');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined audio room successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logMessage('Failed to join audio room: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join audio room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveAudioRoom() async {
    if (!_isInAudioRoom) {
      _logMessage('Not currently in audio room');
      return;
    }

    try {
      _logMessage('Leaving audio room...');

      await _cleanupZegoEngine();

      setState(() {
        _isInAudioRoom = false;
        _isMicrophoneEnabled = false;
        _isSpeakerMuted = false;
      });

      _logMessage('Successfully left audio room');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Left audio room'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _logMessage('Error leaving audio room: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving audio room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleMicrophone() async {
    if (!_isInAudioRoom) {
      _logMessage('Cannot toggle microphone - not in audio room');
      return;
    }

    try {
      if (_isMicrophoneEnabled) {
        _logMessage('Disabling microphone...');
        await ZegoExpressEngine.instance.muteMicrophone(true);
      } else {
        _logMessage('Enabling microphone...');
        await ZegoExpressEngine.instance.muteMicrophone(false);
      }

      setState(() {
        _isMicrophoneEnabled = !_isMicrophoneEnabled;
      });

      _logMessage(
        'Microphone ${_isMicrophoneEnabled ? 'enabled' : 'disabled'}',
      );
    } catch (e) {
      _logMessage('Failed to toggle microphone: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle microphone: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleSpeaker() async {
    if (!_isInAudioRoom) {
      _logMessage('Cannot toggle speaker - not in audio room');
      return;
    }

    try {
      if (_isSpeakerMuted) {
        _logMessage('Unmuting speaker...');
        await ZegoExpressEngine.instance.muteSpeaker(false);
      } else {
        _logMessage('Muting speaker...');
        await ZegoExpressEngine.instance.muteSpeaker(true);
      }

      setState(() {
        _isSpeakerMuted = !_isSpeakerMuted;
      });

      _logMessage('Speaker ${_isSpeakerMuted ? 'muted' : 'unmuted'}');
    } catch (e) {
      _logMessage('Failed to toggle speaker: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle speaker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zego Audio Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current user info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current User',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${widget.userName}'),
                    Text('ID: ${widget.userId}'),
                    Text('Room: $TEST_ROOM_ID'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Status indicators
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isInAudioRoom
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: _isInAudioRoom ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text('In Audio Room: ${_isInAudioRoom ? 'Yes' : 'No'}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
                          color:
                              _isMicrophoneEnabled ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Microphone: ${_isMicrophoneEnabled ? 'On' : 'Off'}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _isSpeakerMuted ? Icons.volume_off : Icons.volume_up,
                          color: _isSpeakerMuted ? Colors.grey : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text('Speaker: ${_isSpeakerMuted ? 'Muted' : 'On'}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Control buttons
            if (!_isInAudioRoom)
              ElevatedButton.icon(
                onPressed: _joinAudioRoom,
                icon: const Icon(Icons.call),
                label: const Text('Join Audio Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleMicrophone,
                      icon: Icon(
                        _isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
                      ),
                      label: Text(
                        _isMicrophoneEnabled ? 'Mute Mic' : 'Unmute Mic',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isMicrophoneEnabled ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleSpeaker,
                      icon: Icon(
                        _isSpeakerMuted ? Icons.volume_off : Icons.volume_up,
                      ),
                      label: Text(
                        _isSpeakerMuted ? 'Unmute Speaker' : 'Mute Speaker',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isSpeakerMuted ? Colors.green : Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _leaveAudioRoom,
                icon: const Icon(Icons.call_end),
                label: const Text('Leave Audio Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Test users list
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Users (Use these on different devices)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Navigate to this screen with different user IDs on different devices to test audio communication.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: testUsers.length,
                          itemBuilder: (context, index) {
                            final user = testUsers[index];
                            final isCurrentUser = user['id'] == widget.userId;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    isCurrentUser ? Colors.blue : Colors.grey,
                                child: Text(user['name']![0]),
                              ),
                              title: Text(user['name']!),
                              subtitle: Text('ID: ${user['id']}'),
                              trailing:
                                  isCurrentUser
                                      ? const Chip(
                                        label: Text('Current'),
                                        backgroundColor: Colors.blue,
                                      )
                                      : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
