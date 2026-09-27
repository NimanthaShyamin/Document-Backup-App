import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service managing device biometric and passcode authentication for security-critical actions.
class BiometricAuthService {
  final LocalAuthentication _auth;

  BiometricAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  /// Checks if the device has biometric hardware or phone passcode capability.
  Future<bool> canAuthenticate() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException catch (e) {
      developer.log('[BiometricAuthService] Capability check failed: $e');
      return false;
    }
  }

  /// Prompts the user to authenticate using biometrics (fingerprint/face) or phone passcode.
  /// If the device does not have authentication support, returns true to prevent lockout.
  Future<bool> authenticate({
    String reason = 'Please authenticate to confirm document deletion.',
  }) async {
    try {
      final isAvailable = await canAuthenticate();
      if (!isAvailable) {
        developer.log('[BiometricAuthService] Biometrics/passcode not supported on this device. Allowing action.');
        return true;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // Allows phone passcode/PIN/pattern if biometrics unavailable
        persistAcrossBackgrounding: true,
      );

      return authenticated;
    } on PlatformException catch (e) {
      developer.log('[BiometricAuthService] Biometric prompt error: $e');
      // If user canceled, return false
      return false;
    } catch (e) {
      developer.log('[BiometricAuthService] Unexpected authentication failure: $e');
      return false;
    }
  }
}
