import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Lifecycle-aware service that elevates device screen brightness to 100% (1.0)
/// on document entry and restores previous system brightness on exit or pause.
class BrightnessControllerService with WidgetsBindingObserver {
  BrightnessControllerService._();
  static final BrightnessControllerService instance = BrightnessControllerService._();

  final ScreenBrightness _screenBrightness = ScreenBrightness();
  double? _cachedPreviousBrightness;
  bool _isMaxBrightnessActive = false;

  /// Returns whether max brightness mode is currently engaged.
  bool get isMaxBrightnessActive => _isMaxBrightnessActive;

  /// Elevates screen brightness to 100% luminance (1.0) and records the initial system brightness.
  Future<void> elevateBrightness() async {
    try {
      if (_isMaxBrightnessActive) return;

      // Cache the current system brightness setting before boosting
      _cachedPreviousBrightness = await _screenBrightness.current;
      developer.log('Cached prior screen brightness: $_cachedPreviousBrightness');

      // Boost luminance to absolute 100% for optical barcode/document scanning
      await _screenBrightness.setScreenBrightness(1.0);
      _isMaxBrightnessActive = true;

      // Register lifecycle observer to monitor app minimize / background switches
      WidgetsBinding.instance.addObserver(this);
    } catch (e, stack) {
      developer.log('Failed to elevate screen brightness', error: e, stackTrace: stack);
    }
  }

  /// Restores previous user brightness setting immediately.
  Future<void> restoreBrightness() async {
    try {
      if (!_isMaxBrightnessActive) return;

      WidgetsBinding.instance.removeObserver(this);

      if (_cachedPreviousBrightness != null) {
        developer.log('Restoring screen brightness to cached level: $_cachedPreviousBrightness');
        await _screenBrightness.setScreenBrightness(_cachedPreviousBrightness!);
      } else {
        await _screenBrightness.resetScreenBrightness();
      }

      _isMaxBrightnessActive = false;
      _cachedPreviousBrightness = null;
    } catch (e, stack) {
      developer.log('Failed to restore screen brightness', error: e, stackTrace: stack);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Dim immediately if user minimizes or switches to another app to save battery and avoid blinding
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_cachedPreviousBrightness != null) {
        _screenBrightness.setScreenBrightness(_cachedPreviousBrightness!);
      }
    } else if (state == AppLifecycleState.resumed && _isMaxBrightnessActive) {
      // Re-boost to 100% if returning to the active document viewer
      _screenBrightness.setScreenBrightness(1.0);
    }
  }
}
