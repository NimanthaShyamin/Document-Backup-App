import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/foreground_scanner_service.dart';

/// Dynamic widget that reflects the live state of AI document scanning.
///
/// Handles:
/// 1. Offline Mode: Stops all countdown timers and displays "Pending AI Scan".
/// 2. Document 1 (Actively scanning): Displays a live linear progress bar & "Scanning Document...".
/// 3. Document 2 (Next in line): Displays live countdown based on the global timer (e.g. "Pending Scan (in 55s)").
/// 4. Document 3+ (Deep queue): Calculates wait time by adding 60s per queue position (e.g. "Pending Scan (in 115s)").
/// 5. Manual override: Provides a "Force Scan Now" button allowing immediate scan execution when online.
class PendingAiScanBadge extends ConsumerWidget {
  final String documentId;
  final bool isDark;

  const PendingAiScanBadge({
    super.key,
    required this.documentId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(foregroundScanStateProvider);
    final isScanningThis = scanState.isScanning(documentId);

    // 1. Actively Scanning this Document
    if (isScanningThis) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blueAccent,
                  ),
                ),
                SizedBox(width: 5),
                Text(
                  'Scanning Document...',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: const SizedBox(
                width: 110,
                height: 2.5,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Global Cooldown Queue wait time calculation
    final waitSeconds = scanState.getWaitSecondsFor(documentId);
    final isCountdownActive = waitSeconds != null && waitSeconds > 0;
    final badgeText = isCountdownActive
        ? 'Pending Scan (in ${waitSeconds}s)'
        : 'Pending AI Scan';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCountdownActive
                    ? Icons.timer_outlined
                    : (!scanState.isOnline
                        ? Icons.cloud_off_rounded
                        : Icons.hourglass_top_rounded),
                color: isDark ? Colors.amberAccent : Colors.amber.shade800,
                size: 10,
              ),
              const SizedBox(width: 4),
              Text(
                badgeText,
                style: TextStyle(
                  color: isDark ? Colors.amberAccent : Colors.amber.shade800,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // Manual Override: Force Scan Now button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!scanState.isOnline) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('Cannot scan while offline. Connect to the internet to scan.'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              ref.read(foregroundScannerServiceProvider.notifier).forceScan(documentId);
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(
                  content: Text('Starting immediate AI Scan...'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: Colors.blueAccent, size: 12),
                  SizedBox(width: 2),
                  Text(
                    'Scan Now',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
