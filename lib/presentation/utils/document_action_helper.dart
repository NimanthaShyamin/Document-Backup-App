import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_preferences_provider.dart';
import '../../domain/entities/vehicle_document.dart';
import '../controllers/document_providers.dart';

/// Helper utility for confirming and securely executing document deletion
/// with optional device biometric / phone passcode authentication.
class DocumentActionHelper {
  /// Confirms deletion with the user, checks biometric policy, authenticates if required,
  /// and deletes the document from local database, sandboxed storage, and cloud sync queue.
  /// Returns `true` if the document was successfully deleted.
  static Future<bool> confirmAndDeleteDocument({
    required BuildContext context,
    required WidgetRef ref,
    required VehicleDocument document,
  }) async {
    // 1. Prompt Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Document?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "${document.title}" (${document.vehicleRegNo})?',
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              'This document will be deleted from your encrypted vault and scheduled for cloud deletion.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return false;
    }

    // 2. Check Biometric / Passcode Security Requirement
    final isBiometricRequired = ref.read(biometricDeleteRequiredProvider);

    if (isBiometricRequired) {
      final authService = ref.read(biometricAuthServiceProvider);
      final authenticated = await authService.authenticate(
        reason: 'Please authenticate with biometrics or passcode to delete "${document.title}".',
      );

      if (!authenticated) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.amberAccent, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Authentication canceled or failed. Deletion aborted for security.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return false;
      }
    }

    // 3. Perform Document Deletion
    try {
      final repo = ref.read(vehicleDocumentRepositoryProvider);
      await repo.deleteDocument(document.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Deleted "${document.title}" from vault.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete document: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }
}
