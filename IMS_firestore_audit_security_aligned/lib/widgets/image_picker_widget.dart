import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';

class ImagePickerWidget extends StatefulWidget {
  final String? initialImageUrl;
  final Function(String imageUrl) onImageUploaded;
  final double size;
  final String folder;
  
  const ImagePickerWidget({
    super.key,
    this.initialImageUrl,
    required this.onImageUploaded,
    this.size = 120,
    this.folder = 'ims_app',
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();
  String? _imageUrl;
  bool _isUploading = false;
  
  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      // Pick image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;
      
      setState(() {
        _isUploading = true;
      });
      
      // Upload to Cloudinary
      String? uploadedUrl;
      
      if (kIsWeb) {
        // For web: read as bytes
        final bytes = await pickedFile.readAsBytes();
        uploadedUrl = await CloudinaryService.uploadImage(
          imageFile: bytes,
          folder: widget.folder,
        );
      } else {
        // For mobile: use File
        final file = File(pickedFile.path);
        uploadedUrl = await CloudinaryService.uploadImage(
          imageFile: file,
          folder: widget.folder,
        );
      }
      
      if (uploadedUrl != null && mounted) {
        setState(() {
          _imageUrl = uploadedUrl;
          _isUploading = false;
        });
        
        widget.onImageUploaded(uploadedUrl);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        setState(() {
          _isUploading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              if (_imageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _imageUrl = null;
                    });
                    widget.onImageUploaded('');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: _isUploading ? null : _showImageSourceDialog,
      child: Stack(
        children: [
          // Image container
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.outline,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _imageUrl != null
                  ? Image.network(
                      CloudinaryService.getOptimizedUrl(
                        _imageUrl!,
                        width: widget.size.toInt(),
                        height: widget.size.toInt(),
                        crop: 'fill',
                      ),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error, size: 40);
                      },
                    )
                  : Icon(
                      Icons.person,
                      size: widget.size * 0.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
          
          // Upload indicator
          if (_isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          
          // Edit button
          if (!_isUploading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
