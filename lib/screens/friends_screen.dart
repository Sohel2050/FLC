import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/screens/game_screen.dart';
import 'package:flutter_chess_app/screens/spectator_screen.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/services/game_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:provider/provider.dart';

class FriendsScreen extends StatefulWidget {
  final ChessUser user;

  const FriendsScreen({super.key, required this.user});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendService _friendService = FriendService();
  final GameService _gameService = GameService();
  final TextEditingController _searchController = TextEditingController();
  List<ChessUser> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
    final results = await _friendService.searchUsers(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Requests'),
            Tab(text: 'Find Players'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildRequestsList(),
          _buildFindPlayersTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
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
                  // if (friend.isOnline)
                  //   IconButton(
                  //     icon: const Icon(Icons.tv),
                  //     onPressed: () async {
                  //       final game = await _gameService.getCurrentGameForUser(
                  //         friend.uid!,
                  //       );
                  //       if (game != null) {
                  //         Navigator.of(context).push(
                  //           MaterialPageRoute(
                  //             builder:
                  //                 (context) =>
                  //                     SpectatorScreen(gameId: game.gameId),
                  //           ),
                  //         );
                  //       } else {
                  //         ScaffoldMessenger.of(context).showSnackBar(
                  //           const SnackBar(
                  //             content: Text('Friend is not in a game.'),
                  //           ),
                  //         );
                  //       }
                  //     },
                  //   ),
                  IconButton(
                    icon: const Icon(Icons.videogame_asset),
                    onPressed: () => _showInviteDialog(friend),
                  ),
                  IconButton(
                    icon: const Icon(Icons.message),
                    onPressed: () {
                      // TODO: Implement chat
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      _friendService.removeFriend(
                        currentUserId: widget.user.uid!,
                        friendUserId: friend.uid!,
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

  Widget _buildRequestsList() {
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
                    onPressed: () {
                      _friendService.acceptFriendRequest(
                        currentUserId: widget.user.uid!,
                        friendUserId: requestUser.uid!,
                      );
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

  Widget _buildFindPlayersTab() {
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
                      icon: const Icon(Icons.person_add),
                      onPressed: () {
                        _friendService.sendFriendRequest(
                          currentUserId: widget.user.uid!,
                          friendUserId: user.uid!,
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

  void _createPrivateGame(ChessUser friend, String gameMode) async {
    final gameProvider = context.read<GameProvider>();

    gameProvider.setLoading(true);
    LoadingDialog.show(
      context,
      message: 'Sending invite...',
      barrierDismissible: false,
      showOnlineCount: true,
      showCancelButton: true,
      onCancel: () => gameProvider.cancelOnlineGameSearch(isFriend: true),
    );
    try {
      await gameProvider.createPrivateGameRoom(
        context: context,
        gameMode: gameMode,
        player1Id: widget.user.uid!,
        player2Id: friend.uid!,
        friendName: friend.displayName,
        player1DisplayName: widget.user.displayName,
        player1PhotoUrl: widget.user.photoUrl,
        player1Rating: widget.user.classicalRating,
      );

      // Wait for game to become active before navigating
      await gameProvider.waitForGameToStart();

      gameProvider.setLoading(false);

      if (mounted) {
        // Hide loading dialog
        LoadingDialog.hide(context);
        // Lets have a small delay to ensure UI is updated
        await Future.delayed(const Duration(milliseconds: 500));
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
