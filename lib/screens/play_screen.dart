import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provoder.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/screens/game_screen.dart';
import 'package:flutter_chess_app/services/admob_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/cpu_difficulty_dialog.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
import 'package:flutter_chess_app/widgets/online_players_count_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../widgets/game_mode_card.dart';
import '../widgets/play_mode_button.dart';

class PlayScreen extends StatefulWidget {
  final ChessUser user;
  final bool isVisible;

  const PlayScreen({super.key, required this.user, this.isVisible = false});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with AutomaticKeepAliveClientMixin {
  int _selectedGameMode = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  NativeAd? _nativeAd;
  bool isAdLoaded = false;
  bool _hasLoadedAd = false;
  bool _isLoadingAd = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('PlayScreen: initState called, isVisible: ${widget.isVisible}');
    // Load ad immediately if screen is initially visible (default tab)
    if (widget.isVisible) {
      debugPrint('PlayScreen: Loading ad on initState');
      _createNativeAd();
    }
  }

  @override
  void didUpdateWidget(PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint(
      'PlayScreen: didUpdateWidget - old: ${oldWidget.isVisible}, new: ${widget.isVisible}',
    );

    // Load ad when screen becomes visible and hasn't loaded yet
    if (widget.isVisible &&
        !oldWidget.isVisible &&
        !_hasLoadedAd &&
        !_isLoadingAd) {
      debugPrint('PlayScreen: Loading ad on visibility change');
      _createNativeAd();
    }
    // Dispose ad when screen becomes invisible to free memory
    else if (!widget.isVisible && oldWidget.isVisible) {
      debugPrint('PlayScreen: Disposing ad on visibility change');
      _disposeNativeAd();
    }
  }

  void _createNativeAd() {
    // Prevent multiple simultaneous ad loads
    if (_isLoadingAd || (_hasLoadedAd && _nativeAd != null)) {
      return;
    }

    // Don't load if ads shouldn't be shown
    if (!AdMobService.shouldShowAds(context, widget.user.removeAds)) {
      return;
    }

    final nativeAdUnitId = AdMobService.getNativeAdUnitId(context);
    if (nativeAdUnitId == null) {
      debugPrint('PlayScreen: Native ad unit ID is null');
      return;
    }

    // Set loading flag to prevent duplicate requests
    _isLoadingAd = true;

    // Dispose existing ad if any
    if (_nativeAd != null) {
      _nativeAd!.dispose();
      _nativeAd = null;
      if (mounted) {
        setState(() {
          isAdLoaded = false;
        });
      }
    }

    _nativeAd = NativeAd(
      adUnitId: nativeAdUnitId,
      request: const AdRequest(),
      factoryId: 'adFactoryNative',
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('PlayScreen: Native ad loaded successfully');
          _isLoadingAd = false;
          _hasLoadedAd = true;
          if (mounted) {
            setState(() {
              isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('PlayScreen: Native ad failed to load: $error');
          ad.dispose();
          _isLoadingAd = false;
          _hasLoadedAd = false;
          if (mounted) {
            setState(() {
              isAdLoaded = false;
            });
          }
          // Don't retry immediately to avoid infinite loops
          // The ad will be retried when the screen becomes visible again
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
    );
    _nativeAd!.load();
  }

  void _disposeNativeAd() {
    debugPrint('PlayScreen: Disposing native ad');
    _nativeAd?.dispose();
    _nativeAd = null;
    _hasLoadedAd =
        false; // Reset flag so ad can load again when screen becomes visible
    _isLoadingAd = false; // Reset loading flag
    if (mounted) {
      setState(() {
        isAdLoaded = false;
      });
    }
  }

  /// Retry loading ad if it failed and screen is visible
  void _retryAdLoad() {
    if (widget.isVisible && !_hasLoadedAd && !_isLoadingAd) {
      debugPrint('PlayScreen: Retrying ad load');
      _createNativeAd();
    }
  }

  /// Debug method to log current ad state
  void _logAdState() {
    debugPrint('PlayScreen Ad State:');
    debugPrint('  - isVisible: ${widget.isVisible}');
    debugPrint('  - _hasLoadedAd: $_hasLoadedAd');
    debugPrint('  - _isLoadingAd: $_isLoadingAd');
    debugPrint('  - isAdLoaded: $isAdLoaded');
    debugPrint('  - _nativeAd != null: ${_nativeAd != null}');
    debugPrint(
      '  - shouldShowAds: ${AdMobService.shouldShowAds(context, widget.user.removeAds)}',
    );
  }

  @override
  void dispose() {
    debugPrint('PlayScreen: Disposing PlayScreen');
    _disposeNativeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final gameProvider = context.read<GameProvider>();
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Online Players Count - Fixed height
            OnlinePlayersCountWidget(),

            // Game Modes Carousel - Responsive height
            SizedBox(
              height: isSmallScreen ? 180 : 220,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: () => _carouselController.previousPage(),
                      ),
                      Expanded(
                        child: CarouselSlider.builder(
                          carouselController: _carouselController,
                          options: CarouselOptions(
                            height: isSmallScreen ? 140 : 170,
                            viewportFraction: 0.8,
                            enlargeCenterPage: true,
                            onPageChanged: (index, reason) {
                              setState(() {
                                _selectedGameMode = index;
                              });
                            },
                          ),
                          itemCount: Constants.gameModes.length,
                          itemBuilder: (context, index, realIndex) {
                            final mode = Constants.gameModes[index];
                            return SizedBox(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: GameModeCard(
                                title: mode[Constants.title],
                                timeControl: mode[Constants.timeControl],
                                isSelected: _selectedGameMode == index,
                                onTap: () {
                                  setState(() {
                                    _selectedGameMode = index;
                                  });
                                  _carouselController.animateToPage(index);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _carouselController.nextPage(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Carousel indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:
                        Constants.gameModes.asMap().entries.map((entry) {
                          return GestureDetector(
                            onTap:
                                () => _carouselController.animateToPage(
                                  entry.key,
                                ),
                            child: Container(
                              width: 8.0,
                              height: 8.0,
                              margin: const EdgeInsets.symmetric(
                                vertical: 4.0,
                                horizontal: 3.0,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black)
                                    .withValues(
                                      alpha:
                                          _selectedGameMode == entry.key
                                              ? 0.9
                                              : 0.4,
                                    ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),

            // Flexible content area for ads
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    // Ad container - Fixed height when ad is loaded
                    if (isAdLoaded && _nativeAd != null)
                      Container(
                        constraints: BoxConstraints(
                          minHeight: isSmallScreen ? 80 : 100,
                          maxHeight: isSmallScreen ? 120 : 140,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: AdWidget(ad: _nativeAd!),
                      )
                    // Show loading indicator while ad is loading (only for premium users to debug)
                    else if (_isLoadingAd &&
                        AdMobService.shouldShowAds(
                          context,
                          widget.user.removeAds,
                        ))
                      Container(
                        height: isSmallScreen ? 80 : 100,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),

                    // Spacer to push buttons to bottom
                    const Spacer(),
                  ],
                ),
              ),
            ),

            // Play buttons - Always at the bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  MainAppButton(
                    text: 'Play Online',
                    icon: Icons.public,
                    onPressed: () async {
                      final selectedMode =
                          Constants.gameModes[_selectedGameMode];
                      final timeControl = selectedMode[Constants.timeControl];
                      final title = selectedMode[Constants.title];
                      final userProvider = context.read<UserProvider>();
                      final currentUser = userProvider.user;
                      final currentClassicalRating =
                          currentUser!.classicalRating;
                      final currentUserTempoRating = currentUser.tempoRating;
                      final currentUserBlitzRating = currentUser.blitzRating;

                      var userRating = currentClassicalRating;

                      // Get the user rating according to the selected game mode
                      if (title == Constants.blitz3 ||
                          title == Constants.blitz5) {
                        userRating = currentUserBlitzRating;
                      } else if (title == Constants.tempo) {
                        userRating = currentUserTempoRating;
                      } else if (title == Constants.classical) {
                        userRating = currentClassicalRating;
                      }

                      LoadingDialog.show(
                        context,
                        message: 'Searching for opponent...',
                        barrierDismissible: false,
                        showOnlineCount: true,
                        showCancelButton: true,
                        onCancel: () => gameProvider.cancelOnlineGameSearch(),
                      );

                      try {
                        await gameProvider.startOnlineGameSearch(
                          userId: currentUser.uid!,
                          displayName: currentUser.displayName,
                          photoUrl: currentUser.photoUrl,
                          playerFlag: currentUser.countryCode ?? '',
                          userRating: userRating,
                          gameMode: timeControl,
                          ratingBasedSearch:
                              context
                                  .read<SettingsProvider>()
                                  .ratingBasedSearch,
                          context: context,
                        );

                        if (context.mounted) {
                          // Wait for game to become active before navigating
                          await gameProvider.waitForGameToStart();

                          gameProvider.setLoading(false);

                          if (context.mounted) {
                            // Hide loading dialog
                            LoadingDialog.hide(context);
                            // Lets have a small delay to ensure UI is updated
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );
                            // Navigate to GameScreen after game is ready
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => GameScreen(user: widget.user),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        gameProvider.setLoading(false);
                        if (context.mounted) {
                          LoadingDialog.hide(context);
                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   SnackBar(
                          //     content: Text('Failed to start online game: $e'),
                          //     backgroundColor: Colors.red,
                          //   ),
                          // );
                        }
                      }
                    },
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 12),

                  MainAppButton(
                    text: 'Play vs CPU',
                    icon: Icons.computer,
                    onPressed: () async {
                      final selectedMode =
                          Constants.gameModes[_selectedGameMode];
                      final timeControl = selectedMode[Constants.timeControl];

                      // Will show loading while initializing Stockfish
                      gameProvider.setLoading(true);
                      LoadingDialog.show(
                        context,
                        message: 'Initializing Stockfish engine...',
                        barrierDismissible: false,
                      );

                      try {
                        // Save game settings to provider
                        await gameProvider.setVsCPU(true);

                        // Initialize Stockfish before showing dialog
                        await gameProvider.initializeStockfish();

                        gameProvider.setLoading(false);

                        if (context.mounted) {
                          // Hide loading dialog
                          LoadingDialog.hide(context);

                          // Show CPU difficulty selection dialog
                          final result = await AnimatedDialog.show(
                            context: context,
                            title: 'Play vs CPU',
                            maxWidth: 400,
                            child: CPUDifficultyDialog(
                              onConfirm: (difficulty, playerColor) {
                                gameProvider.setGameLevel(difficulty);
                                gameProvider.setPlayer(playerColor);
                                gameProvider.setTimeControl(timeControl);

                                // Return the values instead of navigating here
                                Navigator.of(context).pop({
                                  'difficulty': difficulty,
                                  'playerColor': playerColor,
                                });
                              },
                            ),
                          );

                          // Navigate after dialog is closed with result
                          if (result != null && result is Map) {
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          GameScreen(user: widget.user),
                                ),
                              );
                            }
                          }
                        }
                      } catch (e) {
                        gameProvider.setLoading(false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to initialize chess engine: $e',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    isPrimary: false,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 12),

                  MainAppButton(
                    text: 'Local Multiplayer',
                    icon: Icons.people,
                    onPressed: () {
                      final selectedMode =
                          Constants.gameModes[_selectedGameMode];
                      final timeControl = selectedMode[Constants.timeControl];

                      gameProvider.setVsCPU(false); // Ensure vsCPU is false
                      gameProvider.setLocalMultiplayer(true);
                      gameProvider.setTimeControl(timeControl);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GameScreen(user: widget.user),
                        ),
                      );
                    },
                    isPrimary: false,
                    isFullWidth: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
