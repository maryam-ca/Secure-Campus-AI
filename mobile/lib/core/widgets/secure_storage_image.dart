import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Displays an image stored at a *private* Firebase Storage path by
/// calling `ref(path).getDownloadURL()` at render time - this call is
/// itself checked against storage.rules on every invocation, so an
/// unauthorized caller's request fails before any URL is ever produced
/// (unlike a stored public URL, which - once handed out - bypasses
/// access control entirely). See docs/AUDIT_REPORT.md "Security Issues"
/// #1 for the incident this replaced.
///
/// Deliberately does NOT cache the resolved URL across app sessions;
/// Firebase Storage download-URL tokens are cheap to re-fetch and this
/// keeps the security property (an actual rules check every time a
/// viewer opens the alert) rather than trading it for a small
/// performance win.
class SecureStorageImage extends StatelessWidget {
  final String storagePath;
  final double width;
  final double height;
  final BoxFit fit;

  const SecureStorageImage({
    super.key,
    required this.storagePath,
    this.width = 80,
    this.height = 80,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (storagePath.isEmpty) {
      return _placeholder(Icons.image_not_supported_outlined);
    }

    return FutureBuilder<String>(
      future: FirebaseStorage.instance.ref(storagePath).getDownloadURL(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          // Most commonly means the signed-in user's role doesn't pass
          // storage.rules for this path - a real access denial, not a
          // loading glitch, so it's worth a distinct icon.
          return _placeholder(Icons.lock_outline);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _placeholder(Icons.broken_image_outlined),
          ),
        );
      },
    );
  }

  Widget _placeholder(IconData icon) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: AppColors.bodyText),
    );
  }
}
