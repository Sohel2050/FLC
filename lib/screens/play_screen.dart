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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Only load ad if screen is initially visible
    if (widget.isVisible) {
      _createNativeAd();
    }
  }

  @override
  void didUpdateWidget(PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Load ad when screen becomes visible
    if (widget.isVisible && !oldWidget.isVisible) {
      _createNativeAd();
    }
    // Dispose ad when screen becomes invisible
    else if (!widget.isVisible && oldWidget.isVisible) {
      _disposeNativeAd();
    }
  }

  void _createNativeAd() {
    // Don't load if ads shouldn't be shown
    if (!AdMobService.shouldShowAds(context, widget.user.removeAds)) {
      return;
    }

    final nativeAdUnitId = AdMobService.getNativeAdUnitId(context);
    if (nativeAdUnitId == null) {
      return;
    }

    // Dispose existing ad if any
    if (_nativeAd != null) {
      _nativeAd!.dispose();
      _nativeAd = null;
      setState(() {
        isAdLoaded = false;
      });
    }

    _nativeAd = NativeAd(
      adUnitId: nativeAdUnitId,
      request: const AdRequest(),
      factoryId: 'adFactoryNative',
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          setState(() {
            isAdLoaded = true;
          });
          _hasLoadedAd = true;
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // Don't retry immediately to avoid infinite loops
          print('Native ad failed to load: $error');
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
    );
    _nativeAd!.load();
  }

  void _disposeNativeAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _hasLoadedAd = false; // Reset flag so ad can load again
    isAdLoaded = false;
  }

  @override
  void dispose() {
    _disposeNativeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final gameProvider = context.read<GameProvider>();

    return Scaffold(
      body: Column(
        children: [
          // Game Modes Carousel
          Column(
            children: [
              // Container for online people count
              OnlinePlayersCountWidget(),
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
                        height: 220,
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children:
                    Constants.gameModes.asMap().entries.map((entry) {
                      return GestureDetector(
                        onTap:
                            () => _carouselController.animateToPage(entry.key),
                        child: Container(
                          width: 12.0,
                          height: 12.0,
                          margin: const EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 4.0,
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
          const SizedBox(height: 16),

          // Play Buttons
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16.0,
                  children: [
                    Container(
                      child:
                          isAdLoaded
                              ? ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: 100.0,
                                  maxHeight: 150.0,
                                ),
                                child: AdWidget(ad: _nativeAd!),
                              )
                              : SizedBox.shrink(),
                    ),

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
                                      (context) =>
                                          GameScreen(user: widget.user),
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
            ),
          ),
        ],
      ),
    );
  }
}
