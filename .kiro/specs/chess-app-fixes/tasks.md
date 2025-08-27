# Implementation Plan

- [x] 1. Fix PlayScreen Native Ad Loading Issue
  - Fix the visibility tracking logic to properly detect when PlayScreen is initially visible (isVisible = true on app startup)
  - Ensure ad loads when PlayScreen is the default selected tab without removing visibility checks
  - Maintain visibility-dependent logic to prevent multiple ads loading from different screens simultaneously
  - Add proper error handling for ad loading failures and improve _hasLoadedAd flag management
  - Test ad display on fresh app startup while preserving proper lifecycle management
  - _Requirements: 1.1, 1.2, 1.4, 1.5_

- [x] 2. Clean Up Android Manifest Permissions
  - Remove unnecessary permissions from android/app/src/main/AndroidManifest.xml
  - Keep only RECORD_AUDIO, CAMERA, READ_MEDIA_IMAGES, and essential network permissions
  - Remove WRITE_EXTERNAL_STORAGE, BLUETOOTH, WAKE_LOCK permissions
  - _Requirements: 4.1, 4.5_

- [x] 3. Clean Up iOS Info.plist Permissions
  - Review and update iOS permission descriptions in ios/Runner/Info.plist
  - Ensure microphone usage description is specific to voice chat feature
  - Update camera usage description to be specific to profile picture feature
  - _Requirements: 4.1, 4.6_

- [x] 4. Create Permission Service for Runtime Permission Handling
  - Create lib/services/permission_service.dart with microphone, camera, and storage permission methods
  - Implement permission request flows with user-friendly explanations
  - Add methods to check permission status and handle permanently denied permissions
  - Include navigation to app settings when permissions are permanently denied
  - _Requirements: 5.1, 5.2, 5.4, 5.5_

- [x] 5. Remove Audio Controls from Opponent Info Widget
  - Modify _onlineOpponentDataAndTime method in GameScreen to remove AudioControlsWidget
  - Keep only opponent profile, name, rating, and captured pieces display
  - Ensure audio invitation button remains available for starting audio rooms
  - _Requirements: 2.2, 2.5_

- [x] 6. Consolidate Audio Controls to Current User Section Only
  - Ensure _currentUserDataAndTime method in GameScreen keeps AudioControlsWidget
  - Verify audio controls (microphone, speaker, leave audio) are only shown for current user
  - Update UI layout to accommodate consolidated audio controls
  - _Requirements: 2.1, 2.3, 2.4_

- [x] 7. Fix ZegoCloud Engine Initialization
  - Update _initializeZegoEngine method in GameScreen to properly initialize ZegoCloud
  - Implement correct sequence: createEngineWithProfile -> loginRoom -> startPublishingStream
  - Add proper error handling and logging for initialization failures
  - Ensure engine is initialized before attempting to join audio rooms
  - _Requirements: 3.1, 3.7_

- [x] 8. Fix ZegoCloud Audio Stream Management
  - Implement startPublishingStream for sending audio to opponent
  - Implement startPlayingStream for receiving audio from opponent
  - Add proper stream ID management for audio rooms
  - Ensure audio streams are properly started when joining audio rooms
  - _Requirements: 3.2, 3.3_

- [x] 9. Fix Microphone and Speaker Toggle Functionality
  - Update _toggleMicrophone method to properly control ZegoCloud microphone state
  - Update _toggleSpeakerMute method to properly control ZegoCloud speaker state
  - Ensure UI state reflects actual ZegoCloud audio state
  - Add error handling for audio control failures
  - _Requirements: 3.4, 3.5_

- [ ] 10. Implement Proper ZegoCloud Resource Cleanup
  - Update _cleanupZegoEngine method to properly stop streams before logout
  - Ensure stopPublishingStream and stopPlayingStream are called before logoutRoom
  - Add proper error handling for cleanup failures
  - Prevent memory leaks by ensuring all resources are released
  - _Requirements: 3.6_

- [x] 11. Add Permission Requests for Audio Features
  - Integrate PermissionService into audio room invitation flow
  - Request microphone permission before initializing ZegoCloud engine
  - Show permission explanation dialog before requesting microphone access
  - Handle permission denial gracefully with appropriate user feedback
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 12. Add Permission Requests for Camera Features
  - Integrate PermissionService into profile image selection flow
  - Request camera and photo library permissions before opening image picker
  - Show permission explanation dialog before requesting camera access
  - Handle permission denial with fallback options or clear messaging
  - _Requirements: 5.3, 5.4_

- [ ] 13. Test and Validate All Fixes
  - Test PlayScreen ad loading on fresh app install and tab navigation
  - Test audio functionality between two devices with proper microphone/speaker control
  - Test permission request flows on both Android and iOS
  - Verify no unnecessary permissions are requested
  - Validate proper error handling and user feedback for all scenarios
  - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.2, 3.3, 4.1, 5.1_