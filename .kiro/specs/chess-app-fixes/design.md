# Design Document

## Overview

This design addresses critical issues in the Flutter Chess App by implementing fixes for ad display, audio controls, ZegoCloud integration, and permission management. The solution focuses on improving user experience through better state management, cleaner UI design, proper audio functionality, and optimized permission handling.

## Architecture

### Component Structure
```
PlayScreen
├── AdManager (handles ad lifecycle)
├── GameModeCarousel
└── PlayButtons

GameScreen
├── AudioManager (handles ZegoCloud integration)
├── PermissionManager (handles runtime permissions)
├── PlayerInfoWidget (current user only shows audio controls)
└── OpponentInfoWidget (no audio controls)

PermissionService
├── MicrophonePermissionHandler
├── CameraPermissionHandler
└── StoragePermissionHandler
```

### State Management
- Use existing Provider pattern for ad state management
- Implement proper lifecycle management for ZegoCloud engine
- Add permission state tracking in dedicated service

## Components and Interfaces

### 1. PlayScreen Ad Management

**Problem:** Native ads don't load immediately on first visit to PlayScreen.

**Solution:** 
- Fix the visibility tracking logic to properly detect when PlayScreen is initially visible
- Ensure ad loads when PlayScreen is the default selected tab (index 0)
- Maintain visibility checks to prevent multiple ads loading simultaneously
- Add fallback handling for ad load failures

**Key Changes:**
```dart
class _PlayScreenState extends State<PlayScreen> {
  @override
  void initState() {
    super.initState();
    // Load ad immediately if this is the initially visible screen
    if (widget.isVisible) {
      _createNativeAd();
    }
  }
  
  @override
  void didUpdateWidget(PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Properly handle visibility changes
    if (widget.isVisible && !oldWidget.isVisible && !_hasLoadedAd) {
      _createNativeAd();
    }
  }
  
  void _createNativeAd() {
    // Keep visibility checks to prevent conflicts with other screens
    // Fix the initial loading issue while maintaining proper lifecycle
  }
}
```

### 2. Audio Controls Refactoring

**Problem:** Audio controls appear for both current user and opponent, causing UI clutter.

**Solution:**
- Remove audio controls from opponent info widgets
- Consolidate audio controls to current user section only
- Implement audio room invitation system separate from controls

**UI Changes:**
- `_onlineOpponentDataAndTime()`: Remove AudioControlsWidget
- `_currentUserDataAndTime()`: Keep AudioControlsWidget
- Add separate audio invitation button/notification system

### 3. ZegoCloud Audio Integration

**Problem:** Audio functionality not working properly - users can't hear each other.

**Solution:**
- Fix ZegoCloud engine initialization sequence
- Implement proper room joining and audio stream management
- Add comprehensive error handling and logging

**Technical Implementation:**
```dart
class AudioManager {
  Future<void> initializeZegoEngine() async {
    // Proper initialization sequence
    await ZegoExpressEngine.createEngineWithProfile(profile);
    await ZegoExpressEngine.instance.loginRoom(roomID, user);
    
    // Enable audio streams
    await ZegoExpressEngine.instance.startPublishingStream(streamID);
    await ZegoExpressEngine.instance.startPlayingStream(remoteStreamID);
  }
  
  Future<void> toggleMicrophone(bool enable) async {
    await ZegoExpressEngine.instance.muteMicrophone(!enable);
    // Update UI state
  }
}
```

### 4. Permission Management System

**Problem:** App requests unnecessary permissions and doesn't handle runtime permissions properly.

**Solution:**
- Create dedicated PermissionService for runtime permission handling
- Remove unused permissions from manifest files
- Implement permission request flow with user-friendly explanations

**Permission Cleanup:**
- Remove: WRITE_EXTERNAL_STORAGE (not needed for modern Android)
- Remove: BLUETOOTH (not used in current implementation)
- Remove: WAKE_LOCK (not needed)
- Keep: RECORD_AUDIO (for voice chat)
- Keep: CAMERA (for profile pictures)
- Keep: READ_MEDIA_IMAGES (for profile pictures)

## Data Models

### AudioRoomState
```dart
class AudioRoomState {
  final bool isInRoom;
  final bool isMicrophoneEnabled;
  final bool isSpeakerMuted;
  final List<String> participants;
  final String? roomId;
}
```

### PermissionState
```dart
class PermissionState {
  final bool microphoneGranted;
  final bool cameraGranted;
  final bool storageGranted;
  final Map<String, bool> permanentlyDenied;
}
```

## Error Handling

### Ad Loading Errors
- Graceful fallback when ads fail to load
- Prevent layout shifts when ads are not available
- Log errors for debugging without affecting user experience

### Audio Errors
- Clear error messages for ZegoCloud initialization failures
- Automatic retry logic for temporary network issues
- Fallback to text-only communication when audio fails

### Permission Errors
- User-friendly permission request dialogs
- Clear instructions for manually enabling permissions
- Graceful degradation when permissions are denied

## Testing Strategy

### Unit Tests
- AdManager lifecycle and state management
- AudioManager ZegoCloud integration
- PermissionService permission handling logic

### Integration Tests
- PlayScreen ad display flow
- GameScreen audio controls functionality
- Permission request flows

### Manual Testing
- Test ad loading on fresh app install
- Test audio functionality between two devices
- Test permission flows on different Android/iOS versions

## Implementation Phases

### Phase 1: PlayScreen Ad Fix
1. Modify ad loading logic in PlayScreen
2. Test ad display on app startup
3. Verify proper cleanup on screen disposal

### Phase 2: Audio Controls Cleanup
1. Remove audio controls from opponent widgets
2. Consolidate controls to current user section
3. Update UI layout and styling

### Phase 3: ZegoCloud Audio Fix
1. Implement proper ZegoCloud initialization
2. Fix audio stream management
3. Add comprehensive error handling
4. Test audio functionality between devices

### Phase 4: Permission Management
1. Clean up manifest files
2. Implement PermissionService
3. Add runtime permission requests
4. Test permission flows on different devices

## Security Considerations

- Minimize requested permissions to only what's necessary
- Implement proper permission explanations to users
- Ensure audio data is handled securely through ZegoCloud
- Add proper cleanup of audio resources to prevent data leaks