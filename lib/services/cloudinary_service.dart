import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class CloudinaryService {
  // ⚠️ IMPORTANT: Replace these with your actual Cloudinary credentials
  // Get free account at: https://cloudinary.com/users/register/free
  static const String _cloudName = 'YOUR_CLOUD_NAME'; // e.g., 'demo'
  static const String _uploadPreset =
      'YOUR_UPLOAD_PRESET'; // e.g., 'ml_default'

  static const String _apiUrl = 'https://api.cloudinary.com/v1_1';

  /// Upload an image to Cloudinary
  ///
  /// Returns the secure URL of the uploaded image, or null if upload fails.
  ///
  /// Example:
  /// ```dart
  /// final url = await CloudinaryService.uploadImage(
  ///   imageFile: pickedFile,
  ///   folder: 'profile_pictures',
  /// );
  /// ```
  static Future<String?> uploadImage({
    required dynamic imageFile, // Can be File or Uint8List (for web)
    String folder = 'ims_app',
    String? publicId,
  }) async {
    try {
      final url = Uri.parse('$_apiUrl/$_cloudName/image/upload');

      var request = http.MultipartRequest('POST', url);

      // Add upload preset (required for unsigned uploads)
      request.fields['upload_preset'] = _uploadPreset;

      // Add optional folder
      request.fields['folder'] = folder;

      // Add optional public ID (custom filename)
      if (publicId != null) {
        request.fields['public_id'] = publicId;
      }

      // Add timestamp for cache busting
      request.fields['timestamp'] = DateTime.now().millisecondsSinceEpoch
          .toString();

      // Handle different file types (File for mobile, Uint8List for web)
      if (kIsWeb) {
        // Web: imageFile is Uint8List
        final bytes = imageFile as List<int>;
        final mimeType = lookupMimeType('', headerBytes: bytes) ?? 'image/jpeg';

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'upload.jpg',
            contentType: _getMimeType(mimeType),
          ),
        );
      } else {
        // Mobile: imageFile is File
        final file = imageFile as File;
        final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';

        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            contentType: _getMimeType(mimeType),
          ),
        );
      }

      // Send request
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);

        // Return secure URL
        return jsonData['secure_url'] as String;
      } else {
        final errorData = await response.stream.bytesToString();
        debugPrint('Cloudinary upload failed: ${response.statusCode}');
        debugPrint('Error: $errorData');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }

  /// Delete an image from Cloudinary by public ID
  ///
  /// Note: This requires authentication. For free tier, consider not deleting
  /// or using Cloudinary's auto-cleanup features.
  static Future<bool> deleteImage(String publicId) async {
    // This requires API secret, so it's better done server-side
    // For now, we'll just return false and rely on Cloudinary's storage management
    debugPrint('Delete operation requires server-side implementation');
    return false;
  }

  /// Generate a transformation URL for image optimization
  ///
  /// Example:
  /// ```dart
  /// final optimizedUrl = CloudinaryService.getOptimizedUrl(
  ///   originalUrl: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
  ///   width: 300,
  ///   height: 300,
  ///   crop: 'fill',
  /// );
  /// ```
  static String getOptimizedUrl(
    String originalUrl, {
    int? width,
    int? height,
    String crop = 'fill',
    String quality = 'auto',
    String format = 'auto',
  }) {
    // Check if it's a Cloudinary URL
    if (!originalUrl.contains('res.cloudinary.com')) {
      return originalUrl;
    }

    // Split the URL at '/upload/'
    final parts = originalUrl.split('/upload/');
    if (parts.length != 2) return originalUrl;

    // Build transformation string
    final transformations = <String>[];

    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    transformations.add('c_$crop');
    transformations.add('q_$quality');
    transformations.add('f_$format');

    final transformString = transformations.join(',');

    // Reconstruct URL with transformations
    return '${parts[0]}/upload/$transformString/${parts[1]}';
  }

  /// Helper to parse MIME type
  static dynamic _getMimeType(String mimeType) {
    // Return parsed MIME type for http package
    final parts = mimeType.split('/');
    return parts.length == 2 ? parts : null;
  }
}

// Debug print helper
void debugPrint(String message) {
  if (kDebugMode) {
    print('[Cloudinary] $message');
  }
}
