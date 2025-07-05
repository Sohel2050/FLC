import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final UserService _userService = UserService();
  String _selectedRatingType =
      Constants.classicalRating; // Default to classical

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Rankings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: _buildRatingTypeSelector(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _firestore
                .collection(Constants.usersCollection)
                .orderBy(_selectedRatingType, descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No players found.'));
          }

          final users =
              snapshot.data!.docs.map((doc) {
                return ChessUser.fromMap(doc.data() as Map<String, dynamic>);
              }).toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final rating = user.toMap()[_selectedRatingType] ?? 1200;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Text(
                    '#${index + 1}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  title: Text(
                    user.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    'Rating: $rating',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  trailing: ProfileImageWidget(
                    imageUrl: user.photoUrl,
                    radius: 20,
                    isEditable: false,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRatingTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRatingButton(Constants.classicalRating, 'Classical'),
          _buildRatingButton(Constants.blitzRating, 'Blitz'),
          _buildRatingButton(Constants.tempoRating, 'Tempo'),
        ],
      ),
    );
  }

  Widget _buildRatingButton(String ratingType, String label) {
    final bool isSelected = _selectedRatingType == ratingType;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedRatingType = ratingType;
          });
        }
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color:
            isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // Firestore instance for StreamBuilder
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
}
