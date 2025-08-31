import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/admob_provider.dart';
import 'package:flutter_chess_app/services/native_ad_coordinator.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/screens/chat_screen.dart';
import 'package:flutter_chess_app/screens/game_screen.dart';
import 'package:flutter_chess_app/services/admob_service.dart';
import 'package:flutter_chess_app/services/chat_service.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/guest_widget.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:flutter_chess_app/widgets/unread_badge_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

class FriendsScreen extends StatefulWidget {
  final ChessUser user;
  final int initialTabIndex;
  final bool isVisible;

  const FriendsScreen({
    super.key,
    required this.user,
    this.initialTabIndex = 0,
    this.isVisible = false,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<ChessUser> _searchResults = [];
  bool _isSearching = false;

  @override
  bool get wantKeepAlive => true;

  NativeAd? _nativeAd;
  bool isAdLoaded = false;
  bool _hasLoadedAd = false;
  bool _isLoadingAd = false;

  // Listener for app launch sequence completion
  VoidCallback? _appLaunchSequenceListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      initialIndex: widget.initialTabIndex,
      length: 4,
      vsync: this,
    );

    // Set up listener for app launch sequence completion
    _setupAppLaunchSequenceListener();

    // Use post-frame callback to ensure widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isVisible) {
        _attemptNativeAdLoad();
      }
    });
  }

  @override
  void didUpdateWidget(FriendsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Load ad when screen becomes visible and hasn't loaded yet
    if (widget.isVisible &&
        !oldWidget.isVisible &&
        !_hasLoadedAd &&
        !_isLoadingAd) {
      // Use post-frame callback to ensure proper timing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isVisible) {
          _attemptNativeAdLoad();
        }
      });
    }
    // Dispose ad when screen becomes invisible to free memory
    else if (!widget.isVisible && oldWidget.isVisible) {
      _disposeNativeAd();
    }
  }

  /// Set up listener for app launch sequence completion
  void _setupAppLaunchSequenceListener() {
    _appLaunchSequenceListener = () {
      if (mounted && widget.isVisible && !_hasLoadedAd && !_isLoadingAd) {
        _createNativeAd();
      }
    };

    // Add listener to AdMobProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.mounted) {
        final adMobProvider = context.read<AdMobProvider>();
        adMobProvider.addListener(_appLaunchSequenceListener!);
      }
    });
  }

  /// Attempt to load native ad when screen is visible
  void _attemptNativeAdLoad() {
    if (!mounted || !widget.isVisible) {
      return;
    }
    try {
      final adMobProvider = context.read<AdMobProvider>();
      // Check if app launch sequence is in progress
      if (adMobProvider.isAppLaunchSequenceInProgress()) {
        // Don't load now, the listener will trigger when sequence completes
        return;
      }
      _createNativeAd();
    } catch (e) {
      // Fallback to direct loading if provider access fails
      _createNativeAd();
    }
  }

  void _disposeNativeAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _hasLoadedAd =
        false; // Reset flag so ad can load again when screen becomes visible
    _isLoadingAd = false; // Reset loading flag

    // Only call setState if widget is still mounted and not being disposed
    if (mounted && context.mounted) {
      setState(() {
        isAdLoaded = false;
      });
    }
  }

  void _createNativeAd() {
    try {
      // Prevent multiple simultaneous ad loads
      if (_isLoadingAd || (_hasLoadedAd && _nativeAd != null)) {
        return;
      }

      // Validate context and mounting state
      if (!mounted || !context.mounted) {
        return;
      }

      // Don't load if ads shouldn't be shown
      try {
        if (!AdMobService.shouldShowAds(context, widget.user.removeAds)) {
          return;
        }
      } catch (adServiceError) {
        // Log error and skip ad loading
        return;
      }

      // Final check for app launch sequence before loading
      try {
        final adMobProvider = context.read<AdMobProvider>();
        if (adMobProvider.isAppLaunchSequenceInProgress()) {
          return;
        }
      } catch (providerError) {
        // Log error and skip ad loading
        return;
      }

      String? nativeAdUnitId;
      try {
        nativeAdUnitId = AdMobService.getNativeAdUnitId(context);
      } catch (adUnitError) {
        // Log error and skip ad loading
        return;
      }

      if (nativeAdUnitId == null || nativeAdUnitId.isEmpty) {
        return;
      }

      // Set loading flag to prevent duplicate requests
      _isLoadingAd = true;

      // Dispose existing ad if any
      if (_nativeAd != null) {
        try {
          _nativeAd!.dispose();
        } catch (disposeError) {
          // Log error but continue
        }
        _nativeAd = null;
        if (mounted && context.mounted) {
          try {
            setState(() {
              isAdLoaded = false;
            });
          } catch (stateError) {
            // Log error but continue
          }
        }
      }

      try {
        _nativeAd = NativeAd(
          adUnitId: nativeAdUnitId,
          request: const AdRequest(),
          factoryId: 'adFactoryNative',
          listener: NativeAdListener(
            onAdLoaded: (ad) {
              try {
                _isLoadingAd = false;
                _hasLoadedAd = true;

                if (mounted && context.mounted) {
                  setState(() {
                    isAdLoaded = true;
                  });
                }
              } catch (e) {
                _isLoadingAd = false;
                _hasLoadedAd = false;
              }
            },
            onAdFailedToLoad: (ad, error) {
              try {
                ad.dispose();
                _isLoadingAd = false;
                _hasLoadedAd = false;

                if (mounted && context.mounted) {
                  setState(() {
                    isAdLoaded = false;
                  });
                }
                // Don't retry immediately to avoid infinite loops
                // The ad will be retried when the screen becomes visible again
              } catch (e) {
                _isLoadingAd = false;
                _hasLoadedAd = false;
              }
            },
            onAdClicked: (ad) {
              // Ad clicked - no action needed
            },
            onAdImpression: (ad) {
              // Ad impression recorded - no action needed
            },
          ),
          nativeTemplateStyle: NativeTemplateStyle(
            templateType: TemplateType.small,
          ),
        );

        _nativeAd!.load();
      } catch (adCreationError) {
        _isLoadingAd = false;
        _hasLoadedAd = false;
        _nativeAd = null;
      }
    } catch (e) {
      _isLoadingAd = false;
      _hasLoadedAd = false;
      try {
        _nativeAd?.dispose();
      } catch (disposeError) {
        // Log error but continue
      }
      _nativeAd = null;
    }
  }

  @override
  void dispose() {
    // Remove app launch sequence listener
    if (_appLaunchSequenceListener != null) {
      try {
        final adMobProvider = context.read<AdMobProvider>();
        adMobProvider.removeListener(_appLaunchSequenceListener!);
      } catch (e) {
        // Error removing listener during dispose - this is acceptable
      }
      _appLaunchSequenceListener = null;
    }

    // Release native ad permission
    NativeAdCoordinator.releasePermission('FriendsScreen');

    _tabController.dispose();
    _searchController.dispose();

    // Dispose ad without calling setState since widget is being disposed
    _nativeAd?.dispose();
    _nativeAd = null;
    _hasLoadedAd = false;
    _isLoadingAd = false;

    super.dispose();
  }

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    final results = await _friendService.searchUsers(query, widget.user.uid!);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  // show firendRequest Dialog
  void showAcceptRequestDialog({required ChessUser friend}) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Accept Friend Request',
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Decline'),
        ),

        ElevatedButton(
          onPressed: () {
            _friendService.acceptFriendRequest(
              currentUserId: widget.user.uid!,
              friendUserId: friend.uid!,
            );
            // pop the dialog
            Navigator.pop(context);
          },
          child: const Text('Accept'),
        ),
      ],
      child: Text(
        'Do you want to accept the friend request from ${friend.displayName}?',
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Friends'),
            Tab(
              child: StreamBuilder<List<ChessUser>>(
                stream:
                    widget.user.isGuest
                        ? Stream.value([])
                        : _friendService.getFriendRequests(widget.user.uid!),
                builder: (context, snapshot) {
                  final requestCount = snapshot.data?.length ?? 0;
                  return UnreadBadgeWidget(
                    count: requestCount,
                    child: Text('Requests'),
                  );
                },
              ),
            ),
            const Tab(text: 'Find Players'),
            const Tab(text: 'Blocked'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildRequestsList(),
          _buildFindPlayersTab(),
          _buildBlockedUsersList(),
        ],
      ),
      bottomNavigationBar: Container(
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
    );
  }

  Widget _buildFriendsList() {
    if (widget.user.isGuest) {
      return GuestWidget(context: context);
    } else {
      return StreamBuilder<List<ChessUser>>(
        stream: _friendService.getFriends(widget.user.uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no friends yet.'));
          }
          final friends = snapshot.data!;
          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: ProfileImageWidget(
                  imageUrl: friend.photoUrl,
                  radius: 20,
                ),
                title: Text(friend.displayName),
                subtitle: Text(friend.isOnline ? 'Online' : 'Offline'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.videogame_asset),
                      onPressed: () => _showInviteDialog(friend),
                    ),
                    StreamBuilder<int>(
                      stream: _chatService.getUnreadMessageCount(
                        _chatService.getChatRoomId(
                          widget.user.uid!,
                          friend.uid!,
                        ),
                        widget.user.uid!,
                      ),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        return UnreadBadgeWidget(
                          count: unreadCount,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => ChatScreen(
                                        currentUser: widget.user,
                                        otherUser: friend,
                                      ),
                                ),
                              );
                            },
                            child: Icon(Icons.message),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _showRemoveFriendDialog(friend),
                    ),
                    IconButton(
                      icon: const Icon(Icons.block),
                      onPressed: () => _showBlockUserDialog(friend),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  Widget _buildRequestsList() {
    if (widget.user.isGuest) {
      return GuestWidget(context: context);
    } else {
      return StreamBuilder<List<ChessUser>>(
        stream: _friendService.getFriendRequests(widget.user.uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No new friend requests.'));
          }
          final requests = snapshot.data!;
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final requestUser = requests[index];
              return ListTile(
                leading: ProfileImageWidget(
                  imageUrl: requestUser.photoUrl,
                  radius: 20,
                ),
                title: Text(requestUser.displayName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        // show friend request dialog'
                        showAcceptRequestDialog(friend: requestUser);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        _friendService.declineFriendRequest(
                          currentUserId: widget.user.uid!,
                          friendUserId: requestUser.uid!,
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  Widget _buildFindPlayersTab() {
    if (widget.user.isGuest) {
      return GuestWidget(context: context);
    } else {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search for players',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchUsers('');
                          },
                        )
                        : null,
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 10),
            if (_isSearching)
              const CircularProgressIndicator()
            else if (_searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];

                    return ListTile(
                      leading: ProfileImageWidget(
                        imageUrl: user.photoUrl,
                        radius: 20,
                      ),
                      title: Text(user.displayName),
                      trailing: IconButton(
                        icon: Icon(Icons.person_add),
                        onPressed: () {
                          showFriendRequestDialog(
                            currentUserId: widget.user.uid!,
                            friendUserId: user.uid!,
                            friendName: user.displayName,
                          );
                        },
                      ),
                    );
                  },
                ),
              )
            else if (_searchController.text.isNotEmpty)
              const Text('No users found.'),
          ],
        ),
      );
    }
  }

  void showFriendRequestDialog({
    required String currentUserId,
    required String friendUserId,
    required String friendName,
  }) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Send Friend Request',
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),

          child: const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed: () {
            _friendService.sendFriendRequest(
              currentUserId: widget.user.uid!,
              friendUserId: friendUserId,
            );
            // pop the dialog
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
      child: Text(
        'Send a friend request to $friendName',
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showInviteDialog(ChessUser friend) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Invite ${friend.displayName} to a game',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children:
            Constants.gameModes.map((mode) {
              return ListTile(
                title: Text(mode['title'] as String),
                onTap: () {
                  Navigator.of(context).pop();
                  _createPrivateGame(friend, mode['timeControl'] as String);
                },
              );
            }).toList(),
      ),
    );
  }

  void _showRemoveFriendDialog(ChessUser friend) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Remove ${friend.displayName}?',
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _friendService.removeFriend(
              currentUserId: widget.user.uid!,
              friendUserId: friend.uid!,
            );
          },
          child: const Text('Remove'),
        ),
      ],
      child: Text(
        'Are you sure you want to remove ${friend.displayName} from your friends list?',
      ),
    );
  }

  void _showBlockUserDialog(ChessUser friend) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Block ${friend.displayName}?',
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _friendService.blockUser(
              currentUserId: widget.user.uid!,
              blockedUserId: friend.uid!,
            );
          },
          child: const Text('Block'),
        ),
      ],
      child: Text(
        'Are you sure you want to block ${friend.displayName} from your friends list?',
      ),
    );
  }

  Widget _buildBlockedUsersList() {
    if (widget.user.isGuest) {
      return GuestWidget(context: context);
    } else {
      return StreamBuilder<List<ChessUser>>(
        stream: _friendService.getBlockedUsers(widget.user.uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no blocked users.'));
          }
          final blockedUsers = snapshot.data!;
          return ListView.builder(
            itemCount: blockedUsers.length,
            itemBuilder: (context, index) {
              final blockedUser = blockedUsers[index];
              return ListTile(
                leading: ProfileImageWidget(
                  imageUrl: blockedUser.photoUrl,
                  radius: 20,
                ),
                title: Text(blockedUser.displayName),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () => _showUnblockUserDialog(blockedUser),
                ),
              );
            },
          );
        },
      );
    }
  }

  void _showUnblockUserDialog(ChessUser blockedUser) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Unblock ${blockedUser.displayName}?',
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _friendService.unblockUser(
              currentUserId: widget.user.uid!,
              unblockedUserId: blockedUser.uid!,
            );
          },
          child: const Text('Unblock'),
        ),
      ],
      child: Text(
        'Are you sure you want to unblock ${blockedUser.displayName}?',
      ),
    );
  }

  void _createPrivateGame(ChessUser friend, String gameMode) async {
    final gameProvider = context.read<GameProvider>();

    gameProvider.setLoading(true);
    LoadingDialog.show(
      context,
      message: 'Sending invite...',
      barrierDismissible: false,
      showCancelButton: true,
      onCancel: () => gameProvider.cancelOnlineGameSearch(isFriend: true),
    );
    try {
      await gameProvider.createPrivateGameRoom(
        gameMode: gameMode,
        player1Id: widget.user.uid!,
        player2Id: friend.uid!,
        player1DisplayName: widget.user.displayName,
        player1PhotoUrl: widget.user.photoUrl,
        playerFlag: widget.user.countryCode ?? '',
        player1Rating: widget.user.classicalRating,
      );

      if (mounted) {
        LoadingDialog.updateMessage(
          context,
          'Waiting for ${friend.displayName} to join...',
          showCancelButton: true,
          onCancel: () => gameProvider.cancelOnlineGameSearch(isFriend: true),
        );
      }

      // Wait for game to become active before navigating
      await gameProvider.waitForGameToStart();

      gameProvider.setLoading(false);

      if (mounted) {
        // Hide loading dialog
        LoadingDialog.hide(context);
      }

      // Lets have a small delay to ensure UI is updated
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        // Navigate to GameScreen after game is ready
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(user: widget.user),
          ),
        );
      }
    } catch (e) {
      gameProvider.setLoading(false);
      if (mounted) {
        LoadingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start online game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
