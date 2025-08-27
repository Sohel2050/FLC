# Requirements Document

## Introduction

This specification addresses critical issues in the Flutter Chess App related to ad display, audio controls, ZegoCloud audio functionality, and permission management. The goal is to improve user experience by fixing ad loading issues, streamlining audio controls, ensuring proper audio functionality, and optimizing app permissions.

## Requirements

### Requirement 1: Fix PlayScreen Native Ad Display

**User Story:** As a non-premium user, I want to see native ads immediately when I open the PlayScreen, so that I have a consistent ad experience without needing to navigate away and back.

#### Acceptance Criteria

1. WHEN a non-premium user opens the PlayScreen for the first time THEN the native ad SHALL be displayed immediately
2. WHEN the PlayScreen becomes visible after being hidden THEN the native ad SHALL load and display properly
3. WHEN a premium user opens the PlayScreen THEN no ads SHALL be displayed
4. IF the native ad fails to load THEN the PlayScreen SHALL still function normally without layout issues
5. WHEN the user navigates between tabs THEN the ad loading state SHALL be properly managed to prevent memory leaks

### Requirement 2: Streamline Audio Controls Display

**User Story:** As a user in an online game, I want to see only my own audio controls in the game interface, so that the UI is cleaner and less confusing.

#### Acceptance Criteria

1. WHEN I am in an online game THEN I SHALL only see my own audio controls (microphone, speaker, leave audio)
2. WHEN I view the opponent's information THEN no audio controls SHALL be displayed for the opponent
3. WHEN I am not in an audio room THEN I SHALL see a button to start/invite to audio room
4. WHEN I am in an audio room THEN I SHALL see controls to toggle microphone, speaker, and leave audio
5. IF the opponent starts an audio room THEN I SHALL receive a notification with option to join

### Requirement 3: Fix ZegoCloud Audio Functionality

**User Story:** As a user in an online game, I want the voice chat feature to work properly so that I can communicate with my opponent during the game.

#### Acceptance Criteria

1. WHEN I initialize ZegoCloud engine THEN it SHALL connect successfully to the audio room
2. WHEN I enable my microphone THEN the opponent SHALL be able to hear me
3. WHEN the opponent speaks THEN I SHALL be able to hear them through the speaker
4. WHEN I toggle microphone on/off THEN the state SHALL be reflected correctly in ZegoCloud
5. WHEN I toggle speaker mute/unmute THEN the audio output SHALL be controlled correctly
6. WHEN I leave an audio room THEN all ZegoCloud resources SHALL be properly cleaned up
7. IF ZegoCloud initialization fails THEN the user SHALL receive a clear error message

### Requirement 4: Optimize App Permissions

**User Story:** As a user, I want the app to only request permissions that are actually needed for the features I use, so that I have better privacy and security.

#### Acceptance Criteria

1. WHEN the app starts THEN it SHALL only have permissions that are actively used by app features
2. WHEN I use the voice chat feature THEN the app SHALL request microphone permission
3. WHEN I use the profile image feature THEN the app SHALL request camera and photo library permissions
4. WHEN I use file sharing features THEN the app SHALL request appropriate storage permissions
5. IF a permission is not needed for core functionality THEN it SHALL be removed from the manifest files
6. WHEN a permission is requested THEN the user SHALL receive a clear explanation of why it's needed

### Requirement 5: Implement Proper Permission Handling

**User Story:** As a user, I want to be prompted for permissions only when I actually need to use a feature that requires them, so that I understand why the permission is necessary.

#### Acceptance Criteria

1. WHEN I try to start an audio room THEN the app SHALL check for microphone permission
2. IF microphone permission is not granted THEN the app SHALL request it with a clear explanation
3. WHEN I try to change my profile picture THEN the app SHALL check for camera/photo permissions
4. IF camera/photo permission is denied THEN the app SHALL show an appropriate message and fallback option
5. WHEN permission is permanently denied THEN the app SHALL guide the user to app settings