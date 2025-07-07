import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/assets_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileImageWidget extends StatefulWidget {
  final String? imageUrl;
  final double radius;
  final bool isEditable;
  final Function(File?)? onImageSelected;
  final Color? backgroundColor;
  final IconData? placeholderIcon;

  const ProfileImageWidget({
    super.key,
    this.imageUrl,
    this.radius = 50,
    this.isEditable = false,
    this.onImageSelected,
    this.backgroundColor,
    this.placeholderIcon = Icons.person,
  });

  @override
  State<ProfileImageWidget> createState() => _ProfileImageWidgetState();
}

class _ProfileImageWidgetState extends State<ProfileImageWidget> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }

  ImageProvider? _getImageProvider() {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
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
              if (widget.imageUrl != null || _selectedImage != null)
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
        });
        widget.onImageSelected?.call(_selectedImage);
      }
    } catch (e) {
      print('Error picking image: $e');
      // You can show a snackbar or dialog for error handling
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
    widget.onImageSelected?.call(null);
  }
}
