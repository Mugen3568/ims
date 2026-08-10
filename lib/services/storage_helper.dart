class StorageHelper {
  /// Cleans and validates external cloud storage links (Google Drive / Dropbox)
  static String formatCloudUrl(String rawUrl) {
    String trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    
    // Ensure proper URL scheme
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  /// Extracts Google Drive file ID and converts to direct download link
  static String convertGoogleDriveUrl(String url) {
    // Convert sharing link to direct download link
    // From: https://drive.google.com/file/d/FILE_ID/view?usp=sharing
    // To: https://drive.google.com/uc?export=download&id=FILE_ID
    
    final regex = RegExp(r'/d/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    
    if (match != null && match.groupCount >= 1) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }
    
    return url;
  }

  /// Validates if URL is a supported cloud storage link
  static bool isValidCloudUrl(String url) {
    if (url.isEmpty) return false;
    
    // Check for common cloud storage domains
    final supportedDomains = [
      'drive.google.com',
      'docs.google.com',
      'dropbox.com',
      'onedrive.live.com',
      '1drv.ms',
    ];
    
    return supportedDomains.any((domain) => url.contains(domain));
  }

  /// Gets display name for cloud storage provider
  static String getProviderName(String url) {
    if (url.contains('drive.google.com') || url.contains('docs.google.com')) {
      return 'Google Drive';
    } else if (url.contains('dropbox.com')) {
      return 'Dropbox';
    } else if (url.contains('onedrive') || url.contains('1drv.ms')) {
      return 'OneDrive';
    } else {
      return 'External Link';
    }
  }

  /// Gets icon for cloud storage provider
  static String getProviderIcon(String url) {
    if (url.contains('drive.google.com') || url.contains('docs.google.com')) {
      return '📄'; // Google Drive
    } else if (url.contains('dropbox.com')) {
      return '📦'; // Dropbox
    } else if (url.contains('onedrive') || url.contains('1drv.ms')) {
      return '☁️'; // OneDrive
    } else {
      return '🔗'; // Generic link
    }
  }
}
