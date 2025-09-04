# Stockfish Puzzle Integration Design

## Overview

This design document outlines the integration of Stockfish chess engine into the existing puzzle system to enable dynamic solution calculation and validation. The integration will enhance the current pre-defined solution approach by leveraging engine analysis while maintaining backward compatibility and performance.

## Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Puzzle Board    │───▶│ Enhanced Puzzle │───▶│ Stockfish       │
│ Screen          │    │ Provider        │    │ Engine Service  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Move Validation │    │ Solution Cache  │    │ Engine Analysis │
│ & Feedback      │    │ & Progress      │    │ & Evaluation    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Integration Flow

1. **Puzzle Loading**: Load puzzle with FEN position and objective
2. **Engine Initialization**: Initialize Stockfish for the specific position
3. **Move Validation**: Use both engine analysis and pre-defined solutions
4. **Hint Generation**: Generate hints using engine best moves and pre-defined hints
5. **Solution Discovery**: Accept multiple valid solution paths to the objective

## Components and Interfaces

### 1. Enhanced Puzzle Models

#### PuzzleObjective (New Enum)
```dart
enum PuzzleObjective {
  mateInN,        // Checkmate in N moves
  winMaterial,    // Gain material advantage
  draw,           // Achieve a draw
  findBestMove,   // Find the strongest move
  defend,         // Defend against threats
  promote,        // Promote a pawn
  capture,        // Capture specific piece
}

extension PuzzleObjectiveExtension on PuzzleObjective {
  static PuzzleObjective fromString(String objective) {
    // Parse objective strings like "mate in 2", "win material", etc.
  }
  
  bool isAchieved(String fen, List<String> moves, Stockfish engine) {
    // Use engine to verify if objective is met
  }
}
```

#### Enhanced PuzzleModel
```dart
class PuzzleModel {
  // Existing fields remain unchanged
  final String id;
  final String fen;
  final List<String> solution;  // Single optimal solution
  final String objective;
  final PuzzleDifficulty difficulty;
  final List<String> hints;
  final int rating;
  final List<String> tags;
  
  // No changes needed - keep existing structure
}
```

### 2. Stockfish Engine Service

#### PuzzleEngineService
```dart
class PuzzleEngineService {
  Stockfish? _engine;
  final PuzzleSolutionCache _solutionCache = PuzzleSolutionCache();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Engine lifecycle
  Future<void> initializeForPuzzles();
  Future<void> disposeEngine();
  Future<void> restartEngine();
  
  // Solution management with Firestore integration
  Future<List<String>?> getSolution(String puzzleId) async {
    // 1. Check local cache first
    final cached = _solutionCache.getCached(puzzleId);
    if (cached != null) {
      return cached.solution;
    }
    
    // 2. Check Firestore global solutions
    final firestoreSolution = await _loadFromFirestore(puzzleId);
    if (firestoreSolution != null) {
      await _solutionCache.cache(puzzleId, firestoreSolution);
      return firestoreSolution.solution;
    }
    
    // 3. Only use engine if no cached solution exists
    return await _analyzeWithEngine(puzzleId);
  }
  
  // Engine analysis (only when no cached solution exists)
  Future<List<String>> _analyzeWithEngine(String puzzleId);
  Future<void> _saveToFirestore(String puzzleId, List<String> solution);
  Future<CachedSolution?> _loadFromFirestore(String puzzleId);
  
  // Move validation using cached solution first
  Future<MoveValidationResult> validateMove(
    String puzzleId,
    List<String> userMoves,
    String newMove,
  ) async {
    // Check cached solution first
    final solution = await getSolution(puzzleId);
    if (solution != null) {
      final moveIndex = userMoves.length;
      if (moveIndex < solution.length && solution[moveIndex] == newMove) {
        return MoveValidationResult(
          isValid: true,
          achievesObjective: moveIndex + 1 == solution.length,
          isOptimal: true,
          feedback: 'Correct move from verified solution',
        );
      }
      return MoveValidationResult(
        isValid: false,
        achievesObjective: false,
        isOptimal: false,
        feedback: 'Incorrect move. Expected: ${solution[moveIndex]}',
      );
    }
    
    // Fallback to pre-defined solution validation
    return MoveValidationResult(
      isValid: false,
      achievesObjective: false,
      isOptimal: false,
      feedback: 'Solution not available',
    );
  }
  
  // Hint generation using cached hints first
  Future<String?> generateHint(String puzzleId, List<String> userMoves, int level) async {
    // Try cached hints first
    final cached = _solutionCache.getCached(puzzleId);
    if (cached != null && cached.hints.length > level) {
      return cached.hints[level];
    }
    
    // Get solution and provide contextual hint
    final solution = await getSolution(puzzleId);
    if (solution != null && userMoves.length < solution.length) {
      final nextMove = solution[userMoves.length];
      return 'Try: $nextMove';
    }
    
    return null;
  }
}
```

#### EngineAnalysis Model
```dart
class EngineAnalysis {
  final String fen;
  final String bestMove;
  final double evaluation;
  final int depth;
  final List<String> principalVariation;
  final DateTime timestamp;
  final Duration analysisTime;
  
  bool get isMate => evaluation.abs() > 1000;
  int get mateInMoves => isMate ? (evaluation > 0 ? 
    (1001 - evaluation).round() : (evaluation + 1001).round()) : 0;
}
```

#### MoveValidationResult Model
```dart
class MoveValidationResult {
  final bool isValid;
  final bool achievesObjective;
  final bool isOptimal;
  final String? feedback;
  final List<String> alternativeMoves;
  final double evaluationChange;
  
  const MoveValidationResult({
    required this.isValid,
    required this.achievesObjective,
    required this.isOptimal,
    this.feedback,
    this.alternativeMoves = const [],
    this.evaluationChange = 0.0,
  });
}
```

#### EngineHint Model
```dart
class EngineHint {
  final String move;
  final String explanation;
  final double confidence;
  final HintType type;
  
  enum HintType {
    bestMove,
    tactical,
    positional,
    defensive,
  }
}
```

### 3. Enhanced Puzzle Provider

#### Updated PuzzleProvider
```dart
class PuzzleProvider extends ChangeNotifier {
  final PuzzleEngineService _engineService = PuzzleEngineService();
  final PuzzleService _puzzleService = PuzzleService();
  
  // Engine state
  bool _engineInitialized = false;
  bool _engineAnalyzing = false;
  bool _fallbackMode = false;
  
  // Current puzzle state
  PuzzleSession? _currentSession;
  EngineAnalysis? _currentAnalysis;
  List<EngineHint> _availableHints = [];
  
  // Enhanced methods
  Future<void> initializeEngine();
  Future<void> startPuzzleWithEngine(PuzzleModel puzzle);
  Future<MoveValidationResult> validateMoveWithEngine(String move);
  Future<EngineHint> requestEngineHint();
  Future<void> analyzeCurrentPosition();
  
  // Fallback handling
  void enableFallbackMode();
  bool get isUsingEngine => _engineInitialized && !_fallbackMode;
  
  // Getters
  bool get engineAnalyzing => _engineAnalyzing;
  bool get engineAvailable => _engineInitialized;
  EngineAnalysis? get currentAnalysis => _currentAnalysis;
}
```

### 4. Enhanced Puzzle Service

#### Updated PuzzleService
```dart
class PuzzleService {
  final PuzzleEngineService _engineService = PuzzleEngineService();
  
  // Enhanced validation with cached solutions priority
  Future<bool> validateMoveEnhanced(
    PuzzleModel puzzle,
    List<String> userMoves,
    String newMove,
  ) async {
    try {
      // Check cached solution first (Firestore + local)
      final result = await _engineService.validateMove(
        puzzle.id,
        userMoves,
        newMove,
      );
      
      return result.isValid;
    } catch (e) {
      _logger.w('Enhanced validation failed, using fallback: $e');
      // Fallback to original pre-defined solution validation
      return validateMove(puzzle, userMoves, newMove);
    }
  }
  
  // Enhanced puzzle completion check
  Future<bool> isPuzzleSolvedEnhanced(
    PuzzleModel puzzle,
    List<String> userMoves,
  ) async {
    try {
      // Check against cached solution
      final solution = await _engineService.getSolution(puzzle.id);
      
      if (solution != null) {
        return _movesMatchSolution(userMoves, solution);
      }
      
      // Fallback to original check if no cached solution
      return isPuzzleSolved(puzzle, userMoves);
    } catch (e) {
      _logger.w('Enhanced completion check failed, using fallback: $e');
      // Fallback to original check
      return isPuzzleSolved(puzzle, userMoves);
    }
  }
  
  // Enhanced hint system with cached hints priority
  Future<String?> getEnhancedHint(
    PuzzleModel puzzle,
    List<String> userMoves,
    int hintIndex,
  ) async {
    try {
      // Try cached hints first (from Firestore)
      final cachedHint = await _engineService.generateHint(
        puzzle.id,
        userMoves,
        hintIndex,
      );
      
      if (cachedHint != null) {
        return cachedHint;
      }
    } catch (e) {
      _logger.w('Enhanced hint failed, using pre-defined: $e');
    }
    
    // Fallback to pre-defined hints
    return getNextHint(puzzle, hintIndex);
  }
  
  // Helper method to check if user moves match a solution
  bool _movesMatchSolution(List<String> userMoves, List<String> solution) {
    if (userMoves.length != solution.length) return false;
    for (int i = 0; i < userMoves.length; i++) {
      if (userMoves[i] != solution[i]) return false;
    }
    return true;
  }
}
```

## Data Models

### Enhanced Puzzle Data Structure
```json
{
  "puzzles": [
    {
      "id": "beginner_001",
      "fen": "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 4",
      "solution": ["Bxf7+", "Ke7", "Nd5+"],
      "objective": "White to play and win material",
      "parsedObjective": "winMaterial",
      "materialThreshold": 3.0,
      "difficulty": "beginner",
      "rating": 850,
      "hints": [
        "Look for a forcing move that attacks the king",
        "Consider a bishop sacrifice on f7",
        "After Bxf7+ Ke7, you can fork the king and queen with Nd5+"
      ],
      "tags": ["fork", "sacrifice", "tactics"]
    }
  ]
}
```

### Firestore Global Puzzle Solutions Collection

#### Collection: `puzzle_solutions`
```javascript
// Document ID: {puzzleId}
{
  puzzleId: "beginner_001",
  fen: "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 4",
  objective: "White to play and win material",
  
  // Single engine-verified optimal solution
  engineSolution: {
    moves: ["Bxf7+", "Ke7", "Nd5+"],
    evaluation: 3.2,
    depth: 15,
    verifiedAt: Timestamp,
    verifiedBy: "engine_v15.1"
  },
  
  // Engine-generated hints
  engineHints: [
    {
      level: 1,
      hint: "Look for a forcing move that attacks the king",
      move: "Bxf7+",
      confidence: 0.95
    },
    {
      level: 2,
      hint: "The bishop sacrifice opens up tactical opportunities",
      move: "Bxf7+",
      confidence: 0.90
    }
  ],
  
  // Metadata
  difficulty: "beginner",
  rating: 850,
  engineVerified: true,
  lastAnalyzed: Timestamp,
  analysisVersion: "v1.0",
  solveCount: 1247, // How many users have solved this
  
  // Performance data
  averageSolveTime: 45000, // milliseconds
  hintUsageRate: 0.65,
  successRate: 0.78
}
```

### Local Cache Structure
```dart
class PuzzleSolutionCache {
  final Map<String, CachedSolution> _cache = {};
  
  // Cache management
  Future<void> loadFromFirestore(String puzzleId);
  Future<void> saveToFirestore(String puzzleId, EngineSolution solution);
  CachedSolution? getCached(String puzzleId);
  bool hasCachedSolution(String puzzleId);
}

class CachedSolution {
  final String puzzleId;
  final List<String> solution;  // Single optimal solution
  final List<String> hints;     // Cached hints
  final DateTime cachedAt;
}
```

### Engine Configuration
```dart
class PuzzleEngineConfig {
  static const int defaultDepth = 15;
  static const int maxAnalysisTime = 500; // milliseconds
  static const int hintDepth = 12;
  static const int difficultyDepth = 18;
  
  // Engine options for puzzle analysis
  static const Map<String, dynamic> puzzleOptions = {
    'Threads': 1,
    'Hash': 64,
    'Contempt': 0,
    'Skill Level': 20,
    'MultiPV': 3, // For finding multiple good moves
  };
}
```

## Error Handling

### Engine Error Management
```dart
class EngineErrorHandler {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  static Future<T?> withFallback<T>(
    Future<T> Function() engineOperation,
    T Function() fallbackOperation,
  ) async {
    try {
      return await engineOperation();
    } catch (e) {
      _logger.w('Engine operation failed, using fallback: $e');
      return fallbackOperation();
    }
  }
  
  static Future<void> handleEngineFailure(Exception e) async {
    if (e is EngineTimeoutException) {
      // Restart engine with lower settings
      await _restartEngineWithReducedSettings();
    } else if (e is EngineCrashException) {
      // Full engine restart
      await _fullEngineRestart();
    }
  }
}
```

### Fallback Strategies
1. **Engine Unavailable**: Use pre-defined solutions exclusively
2. **Engine Timeout**: Reduce analysis depth and time limits
3. **Engine Crash**: Restart engine and continue with reduced functionality
4. **Analysis Failure**: Cache last known good analysis and use pre-defined hints

## Testing Strategy

### Unit Tests
```dart
// Test engine service functionality
class PuzzleEngineServiceTest {
  void testEngineInitialization();
  void testMoveValidation();
  void testHintGeneration();
  void testDifficultyAssessment();
  void testErrorHandling();
}

// Test enhanced puzzle provider
class EnhancedPuzzleProviderTest {
  void testEngineIntegration();
  void testFallbackMode();
  void testMoveValidationWithEngine();
  void testHintSystemEnhancement();
}
```

### Integration Tests
```dart
class PuzzleEngineIntegrationTest {
  void testCompleteEngineWorkflow();
  void testEngineFailureRecovery();
  void testPerformanceUnderLoad();
  void testMultipleSolutionDetection();
}
```

### Performance Tests
- Engine initialization time (target: < 2 seconds)
- Move validation time (target: < 500ms)
- Hint generation time (target: < 1 second)
- Memory usage during extended sessions
- Battery impact assessment

## Implementation Phases

### Phase 1: Firestore Global Solutions Cache
1. Create Firestore `puzzle_solutions` collection structure
2. Implement PuzzleSolutionCache for local caching
3. Create methods to load/save solutions from/to Firestore
4. Add solution verification and metadata tracking

### Phase 2: Enhanced Engine Service
1. Create PuzzleEngineService with Firestore integration
2. Implement cached-first solution lookup strategy
3. Add engine analysis only for unsolved puzzles
4. Create solution saving mechanism to Firestore

### Phase 3: Smart Move Validation
1. Implement move validation using cached solutions first
2. Add engine validation only when no cached solution exists
3. Save newly discovered solutions to global cache
4. Create fallback to pre-defined solutions

### Phase 4: Enhanced Hint System
1. Implement cached hint lookup from Firestore
2. Generate engine hints only for new puzzles
3. Save generated hints to global cache
4. Combine cached and pre-defined hints

### Phase 5: Performance & Optimization
1. Optimize Firestore queries and caching strategies
2. Implement background solution pre-loading
3. Add solution analytics and usage tracking
4. Fine-tune cache invalidation and updates

### Phase 6: Quality Assurance
1. Migrate existing puzzle solutions to Firestore
2. Validate solution accuracy and completeness
3. Add comprehensive error handling and logging
4. Performance testing with global cache

## Integration Points

### Existing System Compatibility
- **PuzzleModel**: Extend with new fields while maintaining JSON compatibility
- **PuzzleService**: Enhance methods with engine support and fallback
- **PuzzleProvider**: Add engine state management without breaking existing functionality
- **UI Components**: No changes required, enhanced functionality is transparent

### GameProvider Integration
- Reuse existing Stockfish instance when available
- Share engine configuration and lifecycle management
- Coordinate engine usage between game and puzzle modes
- Handle engine conflicts and resource management

### Performance Considerations
- Engine instance sharing between game and puzzle modes
- Analysis result caching to reduce computation
- Background analysis for improved responsiveness
- Memory management for extended puzzle sessions

## Security and Privacy

### Engine Security
- Validate all engine inputs to prevent injection attacks
- Sanitize FEN strings and move notation
- Limit engine analysis time to prevent DoS
- Monitor engine resource usage

### Data Privacy
- Engine analysis results are processed locally
- No puzzle data or analysis sent to external services
- User progress and statistics remain private
- Cache management respects user privacy settings
## Integ
ration Points

### Existing System Compatibility
- **PuzzleModel**: No changes to existing structure, maintain JSON compatibility
- **PuzzleService**: Enhance methods with cached solution priority and engine fallback
- **PuzzleProvider**: Add solution cache management without breaking existing functionality
- **UI Components**: No changes required, enhanced functionality is transparent

### Firestore Integration
- **Global Solutions Cache**: Shared across all users for maximum efficiency
- **Solution Verification**: Track solution accuracy and user success rates
- **Analytics Integration**: Monitor puzzle difficulty and solution discovery
- **Offline Support**: Local cache ensures functionality without internet

### GameProvider Integration
- **Engine Sharing**: Reuse existing Stockfish instance when available
- **Resource Management**: Coordinate engine usage between game and puzzle modes
- **Priority System**: Puzzles use engine only when games are not active
- **Conflict Resolution**: Handle simultaneous engine requests gracefully

### Performance Considerations
- **Cache-First Strategy**: Always check Firestore cache before engine analysis
- **Minimal Engine Usage**: Engine only runs for truly unsolved puzzles
- **Background Loading**: Pre-load popular puzzle solutions
- **Memory Efficiency**: Smart cache eviction and solution compression
- **Network Optimization**: Batch Firestore operations and compress data

## Security and Privacy

### Engine Security
- Validate all engine inputs to prevent injection attacks
- Sanitize FEN strings and move notation
- Limit engine analysis time to prevent DoS
- Monitor engine resource usage

### Data Privacy
- Engine analysis results are processed locally
- Global solution cache improves performance for all users
- No personal puzzle data stored in global cache
- User progress and statistics remain private
- Cache management respects user privacy settings

### Firestore Security Rules
```javascript
// puzzle_solutions collection rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /puzzle_solutions/{puzzleId} {
      // Allow read access to all authenticated users
      allow read: if request.auth != null;
      
      // Allow write only for verified solutions
      allow write: if request.auth != null 
        && isValidSolution(resource.data, request.resource.data);
    }
  }
}

function isValidSolution(existingData, newData) {
  // Validate solution structure and prevent malicious updates
  return newData.keys().hasAll(['puzzleId', 'fen', 'engineSolutions'])
    && newData.puzzleId is string
    && newData.fen is string
    && newData.engineSolutions is list;
}
```