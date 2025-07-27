import 'dart:developer';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/assets_manager.dart';
import 'package:flutter_chess_app/widgets/avatar_selection_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class ProfileImageWidget extends StatefulWidget {
  final String? imageUrl;
  final double radius;
  final bool isEditable;
  final Function(File?)? onImageSelected;
  final Function(String?)? onAvatarSelected;
  final Color? backgroundColor;
  final IconData? placeholderIcon;
  final String? countryCode;

  const ProfileImageWidget({
    super.key,
    this.imageUrl,
    this.radius = 50,
    this.isEditable = false,
    this.onImageSelected,
    this.onAvatarSelected,
    this.backgroundColor,
    this.placeholderIcon = Icons.person,
    this.countryCode,
  });

  @override
  State<ProfileImageWidget> createState() => _ProfileImageWidgetState();
}

class _ProfileImageWidgetState extends State<ProfileImageWidget> {
  File? _selectedImage;
  String? _selectedAvatar;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    log('country code: ${widget.countryCode ?? 'Empty'}');
    return Stack(
      children: [
        CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.backgroundColor ?? Colors.grey[300],
          backgroundImage: _getImageProvider(),
          // child:
          //     _getImageProvider() == null
          //         ? Icon(
          //           widget.placeholderIcon,
          //           size: widget.radius * 0.8,
          //           color: Colors.grey[600],
          //         )
          //         : null,
        ),
        if (widget.isEditable)
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: widget.radius * 0.3,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: IconButton(
                icon: Icon(
                  Icons.camera_alt,
                  size: widget.radius * 0.25,
                  color: Colors.white,
                ),
                onPressed: _showImageSourceDialog,
              ),
            ),
          ),
        if (widget.countryCode != null &&
            widget.countryCode != '' &&
            !widget.isEditable)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: widget.radius * 0.6,
              height: widget.radius * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: CountryFlag.fromCountryCode(
                  widget.countryCode!,
                  height: widget.radius * 0.6,
                  width: widget.radius * 0.6,
                ),
              ),
            ),
          ),
      ],
    );
  }

  ImageProvider? _getImageProvider() {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }
    if (_selectedAvatar != null) {
      return AssetImage(_selectedAvatar!);
    }
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      if (widget.imageUrl!.startsWith('assets')) {
        return AssetImage(widget.imageUrl!);
      }
      return NetworkImage(widget.imageUrl!);
    }
    return AssetImage(AssetsManager.userIcon);
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_search_rounded),
                title: const Text('Choose Avatar'),
                onTap: () {
                  Navigator.pop(context);
                  _chooseAvatar();
                },
              ),
              if (widget.imageUrl != null ||
                  _selectedImage != null ||
                  _selectedAvatar != null)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      try {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80,
        );

        if (image != null) {
          setState(() {
            _selectedImage = File(image.path);
            _selectedAvatar = null;
          });
          widget.onImageSelected?.call(_selectedImage);
          widget.onAvatarSelected?.call(null);
        }
      } catch (e) {
        print('Error picking image: $e');
        // You can show a snackbar or dialog for error handling
      }
    } else {
      // Handle permission denied
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedAvatar = null;
    });
    widget.onImageSelected?.call(null);
    widget.onAvatarSelected?.call(null);
  }

  Future<void> _chooseAvatar() async {
    final selectedAvatar = await AvatarSelectionDialog.show(context: context);
    if (selectedAvatar != null) {
      setState(() {
        _selectedAvatar = selectedAvatar;
        _selectedImage = null;
      });
      widget.onAvatarSelected?.call(selectedAvatar);
      widget.onImageSelected?.call(null);
    }
  }
}
