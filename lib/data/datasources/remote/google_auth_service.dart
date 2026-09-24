import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../../../core/constants/drive_constants.dart';
import '../../../core/errors/exceptions.dart';

/// Dynamic HTTP client forwarding GoogleSignIn OAuth2 Bearer token headers.
/// Automatically calls `account.authHeaders` to acquire or refresh tokens on demand.
class DynamicAuthHttpClient extends http.BaseClient {
  final GoogleSignInAccount _account;
  final http.Client _innerClient = http.Client();

  DynamicAuthHttpClient(this._account);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final headers = await _account.authHeaders;
      request.headers.addAll(headers);
      return await _innerClient.send(request);
    } catch (e, stack) {
      developer.log('Failed to inject auth headers or execute request', error: e, stackTrace: stack);
      throw DriveAuthException('Authentication header acquisition failed: $e', e);
    }
  }

  @override
  void close() {
    _innerClient.close();
    super.close();
  }
}

/// Service managing OAuth2 authentication via Google Sign-In restricted exclusively
/// to the private Google Drive AppData scope.
class GoogleAuthService {
  /// Production OAuth 2.0 Client ID for token exchange & AppData authorization.
  static const String defaultClientId =
      '424892054795-ma02mpie5af38ft8akdl1vctbvoub6nu.apps.googleusercontent.com';

  /// Hidden, isolated application data folder scope.
  static const String driveAppDataScope = DriveConstants.appDataScope;

  final GoogleSignIn _googleSignIn;
  GoogleSignInAccount? _cachedAccount;
  drive.DriveApi? _cachedDriveApi;

  GoogleAuthService({
    GoogleSignIn? googleSignIn,
    String? clientId,
  }) : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              clientId: clientId ?? defaultClientId,
              serverClientId: clientId ?? defaultClientId,
              scopes: const [
                driveAppDataScope,
              ],
            ) {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _cachedAccount = account;
      if (account == null) {
        _cachedDriveApi = null;
      }
    });
  }

  /// Current signed in Google account (null if unauthenticated).
  GoogleSignInAccount? get currentUser => _cachedAccount ?? _googleSignIn.currentUser;

  /// Whether a valid user session is currently available.
  bool get isSignedIn => currentUser != null;

  /// Stream of user account changes (login, logout, account switch).
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => _googleSignIn.onCurrentUserChanged;

  /// Attempts silent authentication on app launch without prompting the user.
  /// Returns the authenticated account if successful, or `null` if interactive login is required.
  Future<GoogleSignInAccount?> signInSilently({bool reAuthenticate = false}) async {
    try {
      developer.log('Attempting Google silent sign-in...');
      final account = await _googleSignIn.signInSilently(reAuthenticate: reAuthenticate);
      _cachedAccount = account;
      if (account != null) {
        developer.log('Silent sign-in successful: ${account.email}');
      } else {
        developer.log('Silent sign-in yielded null; user interaction required.');
      }
      return account;
    } on PlatformException catch (e, stack) {
      developer.log(
        'Silent sign-in PlatformException [${e.code}]: ${e.message}',
        error: e,
        stackTrace: stack,
      );
      return null;
    } on SocketException catch (e, stack) {
      developer.log('Silent sign-in network error: $e', error: e, stackTrace: stack);
      return null;
    } on TimeoutException catch (e, stack) {
      developer.log('Silent sign-in timeout: $e', error: e, stackTrace: stack);
      return null;
    } catch (e, stack) {
      developer.log('Silent sign-in unexpected error: $e', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Prompts the user with the native Google Sign-In sheet, requesting exclusively
  /// the private `drive.appdata` scope.
  Future<GoogleSignInAccount> signIn() async {
    try {
      developer.log('Initiating explicit Google Sign-In for scope $driveAppDataScope...');
      final account = await _googleSignIn.signIn();

      if (account == null) {
        throw const DriveAuthException('Sign-in was cancelled by user.');
      }

      _cachedAccount = account;
      developer.log('Explicit sign-in successful: ${account.email}');
      return account;
    } on PlatformException catch (e, stack) {
      developer.log(
        'Explicit Google Sign-In PlatformException [${e.code}]: ${e.message}',
        error: e,
        stackTrace: stack,
      );

      final code = e.code.toLowerCase();
      if (code == 'sign_in_canceled' ||
          code == '12501' ||
          code.contains('canceled') ||
          code.contains('cancelled')) {
        throw DriveAuthException('Sign-in was cancelled by user.', e);
      } else if (code == 'network_error' ||
          code == '7' ||
          code.contains('network') ||
          code.contains('timeout')) {
        throw DriveAuthException(
          'Network connection error during sign-in. Please verify your internet connection and try again.',
          e,
        );
      } else if (code == '12500' ||
          code == '10' ||
          code.contains('developer_error')) {
        throw DriveAuthException(
          'Google Sign-In configuration error ($code). Please ensure SHA-1 fingerprint and package name match Google Cloud Console.',
          e,
        );
      } else {
        throw DriveAuthException('Google Sign-In failed: ${e.message ?? e.code}', e);
      }
    } on SocketException catch (e, stack) {
      developer.log('Network unreachable during Google Sign-In', error: e, stackTrace: stack);
      throw DriveAuthException(
        'Network unreachable. Please check your internet connection and try again.',
        e,
      );
    } on TimeoutException catch (e, stack) {
      developer.log('Google Sign-In request timed out', error: e, stackTrace: stack);
      throw DriveAuthException(
        'Sign-in request timed out. Please try again.',
        e,
      );
    } catch (e, stack) {
      if (e is DriveAuthException) rethrow;
      developer.log('Explicit Google Sign-In unexpected error', error: e, stackTrace: stack);
      throw DriveAuthException('Failed to sign in with Google: $e', e);
    }
  }

  /// Ensures an active authenticated session exists, attempting silent sign-in first,
  /// falling back to explicit sign-in if needed and permitted.
  Future<GoogleSignInAccount> ensureSignedIn({bool promptIfUnauthenticated = true}) async {
    var account = currentUser;
    if (account != null) return account;

    account = await signInSilently();
    if (account != null) return account;

    if (!promptIfUnauthenticated) {
      throw const DriveAuthException('User is not signed in to Google Drive.');
    }

    return await signIn();
  }

  /// Returns an authenticated HTTP client compatible with the official `googleapis/drive/v3.dart` package.
  /// Automatically injects fresh Bearer headers on every request to handle token expiration seamlessly.
  Future<http.Client> getAuthenticatedClient({bool promptIfUnauthenticated = true}) async {
    final account = await ensureSignedIn(promptIfUnauthenticated: promptIfUnauthenticated);

    try {
      // 1. Attempt official googleapis extension client
      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient != null) {
        return authClient;
      }
    } catch (e) {
      developer.log('googleapis extension client unavailable, falling back to DynamicAuthHttpClient: $e');
    }

    // 2. Dynamic client with on-demand token refresh
    return DynamicAuthHttpClient(account);
  }

  /// Returns an initialized `drive.DriveApi` client authenticated for the current user.
  Future<drive.DriveApi> getDriveApi({bool promptIfUnauthenticated = true}) async {
    if (_cachedDriveApi != null && isSignedIn) {
      return _cachedDriveApi!;
    }

    final client = await getAuthenticatedClient(promptIfUnauthenticated: promptIfUnauthenticated);
    _cachedDriveApi = drive.DriveApi(client);
    return _cachedDriveApi!;
  }

  /// Signs the user out of the application and clears cached API instances.
  Future<void> signOut() async {
    try {
      developer.log('Signing out of Google account...');
      await _googleSignIn.signOut();
      _cachedAccount = null;
      _cachedDriveApi = null;
      developer.log('Google Sign-Out complete.');
    } on PlatformException catch (e, stack) {
      developer.log('Google Sign-Out PlatformException: ${e.code} - ${e.message}', error: e, stackTrace: stack);
      throw DriveAuthException('Sign-out failed: ${e.message ?? e.code}', e);
    } catch (e, stack) {
      developer.log('Error during Google Sign-Out', error: e, stackTrace: stack);
      throw DriveAuthException('Sign-out failed: $e', e);
    }
  }

  /// Disconnects the app entirely from the Google account, revoking all granted scopes.
  Future<void> disconnect() async {
    try {
      developer.log('Disconnecting Google account and revoking scopes...');
      await _googleSignIn.disconnect();
      _cachedAccount = null;
      _cachedDriveApi = null;
      developer.log('Google account disconnected successfully.');
    } on PlatformException catch (e, stack) {
      developer.log('Google Disconnect PlatformException: ${e.code} - ${e.message}', error: e, stackTrace: stack);
      throw DriveAuthException('Disconnect failed: ${e.message ?? e.code}', e);
    } catch (e, stack) {
      developer.log('Error during Google account disconnect', error: e, stackTrace: stack);
      throw DriveAuthException('Disconnect failed: $e', e);
    }
  }
}
