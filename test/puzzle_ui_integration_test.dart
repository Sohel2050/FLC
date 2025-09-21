import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_chess_app/providers/puzzle_provider.dart';
import 'package:flutter_chess_app/providers/settings_provoder.dart';
import 'package:flutter_chess_app/screens/puzzles_screen.dart';
import 'package:flutter_chess_app/screens/puzzle_board_screen.dart';
import 'package:flutter_chess_app/models/puzzle_model.dart';

void main() {
  group('Puzzle UI Integration Tests', () {
    late PuzzleProvider puzzleProvider;
    late SettingsProvider settingsProvider;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      puzzleProvider = PuzzleProvider();
      settingsProvider = SettingsProvider();
    });

    tearDown(() {
      puzzleProvider.dispose();
      settingsProvider.dispose();
    });

    testWidgets('PuzzlesScreen should display difficulty levels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PuzzleProvider>.value(value: puzzleProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: PuzzlesScreen()),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Verify difficulty level cards are displayed
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Expert'), findsOneWidget);

      // Verify rating ranges are displayed
      expect(find.text('800-1000'), findsOneWidget);
      expect(find.text('1000-1200'), findsOneWidget);
      expect(find.text('1200-1400'), findsOneWidget);
      expect(find.text('1400-1600'), findsOneWidget);
      expect(find.text('1600+'), findsOneWidget);
    });

    testWidgets('PuzzleBoardScreen should display puzzle information', (
      WidgetTester tester,
    ) async {
      const testPuzzle = PuzzleModel(
        id: 'ui_test_puzzle',
        fen:
            'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 4',
        solution: ['Bxf7+', 'Ke7', 'Nd5+'],
        objective: 'White to play and win material',
        difficulty: PuzzleDifficulty.beginner,
        hints: [
          'Look for a forcing move that attacks the king',
          'Consider a bishop sacrifice on f7',
          'After Bxf7+ Ke7, you can fork the king and queen',
        ],
        rating: 900,
        tags: ['fork', 'sacrifice', 'tactics'],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PuzzleProvider>.value(value: puzzleProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: PuzzleBoardScreen(puzzle: testPuzzle)),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Verify puzzle information is displayed
      expect(find.text('White to play and win material'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);

      // Verify hint button is present
      expect(find.text('Hint'), findsOneWidget);

      // Verify back button is present
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('Hint button should work correctly', (
      WidgetTester tester,
    ) async {
      const testPuzzle = PuzzleModel(
        id: 'hint_ui_test',
        fen: 'test_fen',
        solution: ['e4'],
        objective: 'Test hint UI',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['Move the pawn to e4'],
        rating: 800,
        tags: ['test'],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PuzzleProvider>.value(value: puzzleProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: PuzzleBoardScreen(puzzle: testPuzzle)),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the hint button
      await tester.tap(find.text('Hint'));
      await tester.pumpAndSettle();

      // Verify hint dialog appears
      expect(find.text('Hint'), findsWidgets);
      expect(find.text('Move the pawn to e4'), findsOneWidget);
    });

    testWidgets(
      'Puzzle completion dialog should appear when puzzle is solved',
      (WidgetTester tester) async {
        const testPuzzle = PuzzleModel(
          id: 'completion_ui_test',
          fen: 'test_fen',
          solution: ['e4'],
          objective: 'Test completion UI',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['Move pawn'],
          rating: 800,
          tags: ['test'],
        );

        // Start the puzzle in the provider
        await puzzleProvider.startPuzzle(testPuzzle);
        await puzzleProvider.makeMove(
          'e4',
          isUserMove: [true],
          expectedUserMoves: 1,
        ); // Solve the puzzle

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PuzzleProvider>.value(
                value: puzzleProvider,
              ),
              ChangeNotifierProvider<SettingsProvider>.value(
                value: settingsProvider,
              ),
            ],
            child: const MaterialApp(
              home: PuzzleBoardScreen(puzzle: testPuzzle),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify completion dialog elements
        expect(find.text('Puzzle Solved!'), findsOneWidget);
        expect(find.text('Next Puzzle'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      },
    );

    testWidgets('Settings integration should work', (
      WidgetTester tester,
    ) async {
      const testPuzzle = PuzzleModel(
        id: 'settings_test',
        fen: 'test_fen',
        solution: ['e4'],
        objective: 'Test settings integration',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['hint'],
        rating: 800,
        tags: ['test'],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PuzzleProvider>.value(value: puzzleProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: PuzzleBoardScreen(puzzle: testPuzzle)),
        ),
      );

      await tester.pumpAndSettle();

      // The screen should render without errors, indicating settings integration works
      expect(find.byType(PuzzleBoardScreen), findsOneWidget);
    });

    testWidgets('Error handling should work gracefully', (
      WidgetTester tester,
    ) async {
      const invalidPuzzle = PuzzleModel(
        id: '',
        fen: '',
        solution: [],
        objective: '',
        difficulty: PuzzleDifficulty.beginner,
        hints: [],
        rating: 0,
        tags: [],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PuzzleProvider>.value(value: puzzleProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(
            home: PuzzleBoardScreen(puzzle: invalidPuzzle),
          ),
        ),
      );

      // Should not crash even with invalid puzzle data
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleBoardScreen), findsOneWidget);
    });
  });
}
