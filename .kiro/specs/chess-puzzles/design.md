# Chess Puzzles Feature Design

## Overview

The chess puzzles feature will be implemented as a new game mode within the existing Flutter chess application. It will provide users with tactical chess problems organized by difficulty levels, complete with hints, progress tracking, and seamless integration with the current game system.

## Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Play Screen   │───▶│ Puzzles Screen  │───▶│ Puzzle Board    │
│                 │    │                 │    │    Screen       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Game Provider   │    │ Puzzle Provider │    │ Puzzle Service  │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Local DB      │    │   Puzzle Data   │    │   Progress      │
│   (Hive/SQLite) │    │   (JSON/Assets) │    │   Storage       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Data Flow

1. **Puzzle Loading**: Puzzles are loaded from local assets or downloaded from remote source
2. **State Management**: PuzzleProvider manages current puzzle state, progress, and user interactions
3. **Move Validation**: Existing game engine validates moves against puzzle solutions
4. **Progress Tracking**: Local storage tracks completion status, times, and statistics

## Components and Interfaces

### 1. Puzzle Data Models

#### PuzzleModel
```dart
class PuzzleModel {
  final String id;
  final String fen;           // Starting position
  final List<String> solution; // Correct move sequence
  final String objective;     // Description (e.g., "Mate in 2")
  final PuzzleDifficulty difficulty;
  final List<String> hints;  // Progressive hints
  final int rating;          // Puzzle rating/difficulty score
  final List<String> tags;   // Categories (tactics, endgame, etc.)
}

enum PuzzleDifficulty {
  beginner,   // Rating 800-1000
  easy,       // Rating 1000-1200
  medium,     // Rating 1200-1400
  hard,       // Rating 1400-1600
  expert      // Rating 1600+
}
```

#### PuzzleProgress
```dart
class PuzzleProgress {
  final String userId;
  final String puzzleId;
  final bool completed;
  final DateTime? completedAt;
  final Duration? solveTime;
  final int hintsUsed;
  final int attempts;
  final bool solvedWithoutHints;
  final PuzzleDifficulty difficulty;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool needsSync; // For offline support
}
```

#### PuzzleStatistics
```dart
class PuzzleStatistics {
  final String userId;
  final int totalPuzzlesSolved;
  final Map<PuzzleDifficulty, DifficultyStats> puzzlesByDifficulty;
  final Duration averageSolveTime;
  final int totalHintsUsed;
  final int perfectSolutions;
  final int longestStreak;
  final DateTime? lastPlayedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class DifficultyStats {
  final int completed;
  final int total;
  final Duration? averageTime;
  final int hintsUsed;
}
```
```

#### PuzzleSession
```dart
class PuzzleSession {
  final PuzzleModel puzzle;
  final List<String> userMoves;
  final int currentMoveIndex;
  final int hintsUsed;
  final DateTime startTime;
  final PuzzleSessionState state;
}

enum PuzzleSessionState {
  active,
  solved,
  failed,
  abandoned
}
```

### 2. Core Services

#### PuzzleService
```dart
class PuzzleService {
  // Data management
  Future<List<PuzzleModel>> loadPuzzlesByDifficulty(PuzzleDifficulty difficulty);
  Future<PuzzleModel?> getPuzzleById(String id);
  Future<void> cachePuzzles(List<PuzzleModel> puzzles);
  
  // Progress tracking (Cloud + Local)
  Future<void> savePuzzleProgress(String userId, PuzzleProgress progress);
  Future<PuzzleProgress?> getPuzzleProgress(String userId, String puzzleId);
  Future<Map<PuzzleDifficulty, int>> getCompletionStats(String userId);
  Future<void> syncProgressToCloud(String userId);
  Future<void> syncProgressFromCloud(String userId);
  
  // Statistics management
  Future<void> updatePuzzleStatistics(String userId, PuzzleProgress progress);
  Future<PuzzleStatistics> getPuzzleStatistics(String userId);
  
  // Solution validation
  bool validateMove(PuzzleModel puzzle, List<String> userMoves, String newMove);
  bool isPuzzleSolved(PuzzleModel puzzle, List<String> userMoves);
  String? getNextHint(PuzzleModel puzzle, int hintIndex);
  
  // Offline support
  Future<void> cacheProgressLocally(String userId, PuzzleProgress progress);
  Future<List<PuzzleProgress>> getPendingSyncProgress(String userId);
  Future<void> markProgressAsSynced(String userId, String puzzleId);
}
```

#### PuzzleProvider (State Management)
```dart
class PuzzleProvider extends ChangeNotifier {
  // Current session state
  PuzzleSession? _currentSession;
  List<PuzzleModel> _availablePuzzles = [];
  Map<PuzzleDifficulty, List<PuzzleProgress>> _progressByDifficulty = {};
  
  // Getters
  PuzzleSession? get currentSession => _currentSession;
  List<PuzzleModel> get availablePuzzles => _availablePuzzles;
  
  // Session management
  Future<void> startPuzzle(PuzzleModel puzzle);
  Future<void> makeMove(String move);
  Future<void> requestHint();
  Future<void> resetPuzzle();
  Future<void> nextPuzzle();
  
  // Progress management
  Future<void> loadProgress();
  Future<void> saveCurrentProgress();
  int getCompletionPercentage(PuzzleDifficulty difficulty);
}
```

### 3. UI Components

#### PuzzlesScreen
- Displays difficulty level selection
- Shows completion statistics for each level
- Provides navigation to puzzle board

#### PuzzleBoardScreen
- Extends existing game board functionality
- Adds puzzle-specific UI elements (objective, hints, progress)
- Integrates with existing board themes and settings

#### PuzzleCompletionDialog
- Shows success message and statistics
- Provides "Next Puzzle" and "Retry" options
- Displays achievement badges for perfect solutions

## Data Models

### Puzzle Data Structure
```json
{
  "puzzles": [
    {
      "id": "puzzle_001",
      "fen": "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 4",
      "solution": ["Bxf7+", "Ke7", "Nd5+"],
      "objective": "White to play and win material",
      "difficulty": "beginner",
      "rating": 900,
      "hints": [
        "Look for a forcing move that attacks the king",
        "Consider a bishop sacrifice on f7",
        "After Bxf7+ Ke7, you can fork the king and queen"
      ],
      "tags": ["fork", "sacrifice", "tactics"]
    }
  ]
}
```

### Firestore Schema

#### Collection: `puzzle_progress`
```javascript
// Document ID: {userId}_{puzzleId}
{
  userId: "user123",
  puzzleId: "puzzle_001",
  completed: true,
  completedAt: Timestamp,
  solveTime: 45000, // milliseconds
  hintsUsed: 1,
  attempts: 2,
  solvedWithoutHints: false,
  difficulty: "beginner",
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

#### Collection: `puzzle_statistics`
```javascript
// Document ID: {userId}
{
  userId: "user123",
  totalPuzzlesSolved: 25,
  puzzlesByDifficulty: {
    beginner: { completed: 10, total: 15 },
    easy: { completed: 8, total: 20 },
    medium: { completed: 5, total: 25 },
    hard: { completed: 2, total: 30 },
    expert: { completed: 0, total: 35 }
  },
  averageSolveTime: 38000,
  totalHintsUsed: 12,
  perfectSolutions: 8, // solved without hints
  longestStreak: 5,
  lastPlayedAt: Timestamp,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Local Storage (Offline Cache)
```sql
-- Local cache for offline access
CREATE TABLE puzzle_progress_cache (
  puzzle_id TEXT PRIMARY KEY,
  user_id TEXT,
  completed INTEGER DEFAULT 0,
  completed_at TEXT,
  solve_time INTEGER,
  hints_used INTEGER DEFAULT 0,
  attempts INTEGER DEFAULT 0,
  solved_without_hints INTEGER DEFAULT 0,
  synced INTEGER DEFAULT 0 -- 0 = needs sync, 1 = synced
);

-- Local statistics cache
CREATE TABLE puzzle_stats_cache (
  user_id TEXT PRIMARY KEY,
  data TEXT, -- JSON string of statistics
  last_synced TEXT,
  needs_sync INTEGER DEFAULT 0
);
```

## Error Handling

### Puzzle Loading Errors
- **Network Failure**: Fallback to cached puzzles, show offline indicator
- **Corrupted Data**: Skip invalid puzzles, log errors for debugging
- **Missing Assets**: Show user-friendly error, provide retry option

### Game State Errors
- **Invalid Moves**: Provide immediate feedback, don't count as attempt
- **State Corruption**: Reset puzzle to initial position, preserve progress
- **Timer Issues**: Use fallback timing mechanism, estimate solve time

### Storage Errors
- **Firestore Write Failures**: Cache locally, queue for sync when online
- **Firestore Read Failures**: Fallback to local cache, show offline indicator
- **Network Connectivity**: Seamless offline/online transitions with sync
- **Sync Conflicts**: Use timestamp-based resolution, preserve user progress
- **Local Storage Failures**: Use in-memory fallback, attempt recovery

## Testing Strategy

### Unit Tests
- **PuzzleService**: Test puzzle loading, validation, and progress tracking
- **PuzzleProvider**: Test state management and user interactions
- **Data Models**: Test serialization, validation, and edge cases

### Integration Tests
- **Puzzle Flow**: Test complete puzzle-solving workflow
- **Progress Persistence**: Test saving and loading progress across sessions
- **Error Recovery**: Test handling of various error conditions

### Widget Tests
- **PuzzlesScreen**: Test difficulty selection and navigation
- **PuzzleBoardScreen**: Test move input and hint display
- **Completion Dialog**: Test button interactions and state updates

### Performance Tests
- **Puzzle Loading**: Measure load times for different puzzle sets
- **Memory Usage**: Monitor memory consumption during extended sessions
- **Battery Impact**: Test power consumption during puzzle solving

## Implementation Phases

### Phase 1: Core Infrastructure
1. Create puzzle data models and services
2. Implement basic puzzle loading and caching
3. Set up Firestore collections and local storage for progress tracking
4. Create puzzle provider for state management
5. Implement offline/online sync mechanism

### Phase 2: UI Implementation
1. Add puzzles button to play screen
2. Create puzzles difficulty selection screen
3. Implement puzzle board screen with basic functionality
4. Add puzzle completion dialog

### Phase 3: Advanced Features
1. Implement hint system with progressive disclosure
2. Add progress tracking and statistics
3. Create puzzle completion animations and feedback
4. Integrate with existing settings and themes

### Phase 4: Polish and Optimization
1. Add puzzle categories and filtering
2. Implement achievement system and leaderboards
3. Add progress sharing and social features
4. Optimize performance and memory usage
5. Add comprehensive error handling and recovery

## Integration Points

### Existing Game System
- **BoardController**: Reuse existing board rendering and interaction
- **GameProvider**: Extend or create parallel provider for puzzle state
- **Settings**: Respect user preferences for themes, animations, and board orientation
- **AdMob**: Integrate ads between puzzle sessions (respecting premium status)

### Navigation
- **Play Screen**: Add puzzles option alongside existing game modes
- **Back Navigation**: Proper handling of puzzle abandonment and progress saving
- **Deep Linking**: Support direct navigation to specific puzzle levels

### Theming and Accessibility
- **Material Design**: Follow existing design patterns and color schemes
- **Accessibility**: Ensure puzzle objectives and hints are screen reader friendly
- **Responsive Design**: Adapt UI for different screen sizes and orientations