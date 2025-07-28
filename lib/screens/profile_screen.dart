import 'dart:developer';
import 'dart:io';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/screens/login_screen.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
import 'package:flutter_chess_app/widgets/play_mode_button.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  final ChessUser user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _displayNameController;
  late TextEditingController _emailController;
  File? _selectedImageFile;
  String? _selectedAvatar;
  late ChessUser _currentUser;
  bool _imageRemoved = false;
  String? _countryCode;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _displayNameController = TextEditingController(
      text: _currentUser.displayName,
    );
    _emailController = TextEditingController(text: _currentUser.email);
    _countryCode = _currentUser.countryCode;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  bool get _isGuest => _currentUser.isGuest;

  void _showCountrySelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setState) {
            List<Map<String, String>> filteredCountries =
                Constants.countries
                    .where(
                      (country) => country['name']!.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();

            return AlertDialog(
              title: const Text('Select Country'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search countries...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredCountries.length,
                        itemBuilder: (context, index) {
                          final country = filteredCountries[index];
                          return ListTile(
                            leading: CountryFlag.fromCountryCode(
                              country['code']!,
                              height: 20,
                              width: 30,
                            ),
                            title: Text(country['name']!),
                            onTap: () {
                              this.setState(() {
                                _countryCode = country['code'];
                              });
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isGuest)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveProfile(userService),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ProfileImageWidget(
              imageUrl: _currentUser.photoUrl,
              radius: 60,
              isEditable: !_isGuest,
              onImageSelected: (file) {
                setState(() {
                  _selectedImageFile = file;
                  // Only reset _selectedAvatar if we're actually selecting an image file
                  if (file != null) {
                    _selectedAvatar = null;
                    _imageRemoved = false;
                  } else {
                    // If file is null, only set _imageRemoved to true if we don't have a selected avatar
                    // This prevents the callback from interfering when selecting an avatar
                    if (_selectedAvatar == null) {
                      _imageRemoved = true;
                    }
                  }
                });
              },

              onAvatarSelected: (avatar) {
                setState(() {
                  _selectedAvatar = avatar;
                  _selectedImageFile = null;
                  if (avatar == null) {
                    // Only set _imageRemoved to true if we don't have a selected image file
                    if (_selectedImageFile == null) {
                      _imageRemoved = true;
                    }
                  } else {
                    _imageRemoved = false;
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            _buildProfileField(
              context,
              label: 'Display Name',
              controller: _displayNameController,
              isEditable: !_isGuest,
              icon: Icons.person,
            ),

            _buildProfileField(
              context,
              label: 'Email',
              controller: _emailController,
              value: _currentUser.email ?? 'N/A',
              isEditable: false,
              icon: Icons.email,
            ),

            if (!_isGuest)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                child: InkWell(
                  onTap: _showCountrySelectionDialog,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.grey),
                        const SizedBox(width: 12),
                        if (_countryCode != null)
                          Row(
                            children: [
                              CountryFlag.fromCountryCode(
                                _countryCode!,
                                height: 24,
                                width: 32,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getCountryName(_countryCode!),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          )
                        else
                          Text(
                            'Select Country',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            const Divider(height: 32),
            _buildRatingInfo(
              context,
              'Classical Rating',
              _currentUser.classicalRating,
            ),
            _buildRatingInfo(context, 'Blitz Rating', _currentUser.blitzRating),
            _buildRatingInfo(context, 'Tempo Rating', _currentUser.tempoRating),
            const Divider(height: 32),
            _buildGameStats(context, 'Games Played', _currentUser.gamesPlayed),
            _buildGameStats(context, 'Games Won', _currentUser.gamesWon),
            _buildGameStats(context, 'Games Lost', _currentUser.gamesLost),
            _buildGameStats(context, 'Games Draw', _currentUser.gamesDraw),
            const SizedBox(height: 32),
            if (_isGuest)
              Column(
                spacing: 16,
                children: [
                  Text(
                    'Sign In or Create an Account to Save Your Progress',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  MainAppButton(
                    text: 'Sign In',
                    icon: Icons.login,
                    isFullWidth: true,
                    onPressed: () {
                      // Navigate to sign in screen and remove all previous routes
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),

            if (!_isGuest)
              Column(
                spacing: 16,
                children: [
                  MainAppButton(
                    text: 'Logout',
                    icon: Icons.logout,
                    isPrimary: false,
                    isFullWidth: true,
                    onPressed: () => _confirmLogout(userService),
                  ),
                  MainAppButton(
                    text: 'Delete Account',
                    icon: Icons.delete,
                    isFullWidth: true,
                    onPressed: () => _confirmDeleteAccount(userService),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _getCountryName(String countryCode) {
    final country = Constants.countries.firstWhere(
      (country) => country['code'] == countryCode,
      orElse: () => {'name': countryCode},
    );
    return country['name']!;
  }

  Widget _buildProfileField(
    BuildContext context, {
    required String label,
    TextEditingController? controller,
    String? value,
    required bool isEditable,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        readOnly: !isEditable,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          suffixIcon:
              isEditable
                  ? IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      // Focus the text field for editing
                      FocusScope.of(context).requestFocus(FocusNode());
                    },
                  )
                  : null,
        ),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  Widget _buildRatingInfo(BuildContext context, String title, int rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(
            rating.toString(),
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStats(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(count.toString(), style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Future<void> _saveProfile(UserService userService) async {
    final newDisplayName = _displayNameController.text.trim();
    String? newPhotoUrl = _currentUser.photoUrl;

    bool hasChanges =
        newDisplayName != _currentUser.displayName ||
        _selectedImageFile != null ||
        _selectedAvatar != null ||
        _imageRemoved ||
        _countryCode != _currentUser.countryCode;

    if (!hasChanges) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No changes to save.')));
      return;
    }

    LoadingDialog.show(context, message: 'Saving profile...');

    try {
      // Store the current values before they get reset
      final currentSelectedAvatar = _selectedAvatar;
      final currentSelectedImageFile = _selectedImageFile;
      final currentImageRemoved = _imageRemoved;

      if (currentImageRemoved) {
        if (_currentUser.photoUrl != null &&
            !_currentUser.photoUrl!.startsWith('assets')) {
          LoadingDialog.updateMessage(context, 'Deleting image...');
          await userService.deleteProfileImage(_currentUser.uid!);
        }
        newPhotoUrl = null;
      } else if (currentSelectedImageFile != null) {
        LoadingDialog.updateMessage(context, 'Uploading image...');
        newPhotoUrl = await userService.uploadProfileImage(
          _currentUser.uid!,
          currentSelectedImageFile,
        );
      } else if (currentSelectedAvatar != null) {
        newPhotoUrl = currentSelectedAvatar;
      }

      final updatedUser = _currentUser.copyWith(
        displayName: newDisplayName,
        photoUrl: newPhotoUrl,
        countryCode: _countryCode,
      );

      if (mounted) {
        LoadingDialog.updateMessage(context, 'Updating profile...');
      }

      await userService.updateUser(updatedUser);

      // Update the UserProvider
      if (mounted) {
        log('Updating user provider: ${updatedUser.photoUrl}');
        Provider.of<UserProvider>(context, listen: false).setUser(updatedUser);
      }

      // Now reset the state AFTER we've used the values
      setState(() {
        _currentUser = updatedUser;
        _selectedImageFile = null;
        _selectedAvatar = null;
        _imageRemoved = false;
      });

      if (mounted) {
        LoadingDialog.hide(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } catch (e) {
      log('Error in _saveProfile: $e');
      if (mounted) {
        LoadingDialog.hide(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
      }
    }
  }

  Future<void> _confirmDeleteAccount(UserService userService) async {
    final confirmed = await AnimatedDialog.show<bool>(
      context: context,
      title: 'Delete Account',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
      child: const Text(
        'Are you sure you want to delete your account? This action cannot be undone.',
        textAlign: TextAlign.center,
      ),
    );

    if (confirmed == true) {
      LoadingDialog.show(context, message: 'Deleting account...');
      try {
        await userService.deleteUserAccount(_currentUser.uid!);
        if (mounted) {
          LoadingDialog.hide(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Account deleted.')));
          // Navigate back to a login/guest screen or home screen as appropriate
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          LoadingDialog.hide(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e')),
          );
        }
      }
    }
  }

  // Confirm logout dialog
  Future<void> _confirmLogout(UserService userService) async {
    final confirmed = await AnimatedDialog.show<bool>(
      context: context,
      title: 'Logout',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Logout'),
        ),
      ],
      child: const Text(
        'Are you sure you want to logout? You will lose any unsaved changes.',
        textAlign: TextAlign.center,
      ),
    );
    if (confirmed == true) {
      // We logout
      await userService.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully.')),
        );
        // Navigate back to a login/guest screen or home screen as appropriate
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
