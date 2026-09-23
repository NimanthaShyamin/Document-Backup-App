# Vehicle Document Vault (Enterprise Flutter Client)

An enterprise-grade, modular, offline-first personal vehicle document repository (specifically targeting Fuel Pass QR codes, digital motor insurance certificates, and revenue licenses). 

Pairs **zero-latency local sandboxed storage** (SQLite via Drift with WAL mode) with **silent background cloud synchronization** using Google Drive's hidden `drive.appdata` scope.

---

## Strict Operational Principles

1. **Zero-Latency Offline-First Startup:**
   - Launching the app never blocks on network I/O. Cached documents render immediately from local SQLite database and sandboxed file storage.
   - Non-blocking delta check runs in parallel to pull remote changes and push pending local changes.
2. **Universal Display Optimization (Global Brightness Elevation):**
   - Ramps device screen luminance to 100% (1.0) when entering `DocumentViewerScreen`.
   - Reverts immediately to cached system brightness upon viewer exit or when the app is paused/backgrounded.
3. **In-App Native Document Presentation:**
   - Multi-page PDFs rendered via `pdfx`.
   - Rasterized certificates (PNG/JPG/WEBP) rendered with pinch-to-zoom pan via `InteractiveViewer`.
   - Vector QR codes rendered natively via `qr_flutter`.
4. **Reliable Offline-to-Cloud Queue Sync:**
   - FIFO queue in SQLite with exponential backoff and jitter ($5s \times 2^n + \text{jitter}$).
   - Silent Google Drive integration restricted exclusively to the private `drive.appdata` hidden scope (`appDataFolder`).
5. **Local Lifecycle Management & Expiry Alerts:**
   - Local alerts scheduled at 30 days, 7 days, and 1 day prior to document expiry via `flutter_local_notifications` and `timezone`.

---

## Directory & Architectural Layout

```
lib/
├── core/
│   ├── constants/drive_constants.dart          # Drive scope & vault paths
│   ├── errors/exceptions.dart                  # Typed domain exceptions
│   ├── hardware/brightness_controller.dart     # Lifecycle-aware screen brightness
│   ├── hardware/notification_engine.dart       # Timezone-aware local notifications
│   ├── storage/file_storage_manager.dart       # Sandboxed app_vault file manager
│   └── utils/crypto_utils.dart                 # SHA-256 computation & verification
├── data/
│   ├── datasources/local/app_database.dart     # Drift SQLite tables (Docs + Queue)
│   ├── datasources/remote/drive_app_data_service.dart # Google Drive AppData v3 client
│   ├── models/remote_document_metadata.dart    # AppData appProperties parser
│   └── repositories/
│       ├── sync_queue_repository_impl.dart     # FIFO queue + delta reconciliation
│       └── vehicle_document_repository_impl.dart # CRUD + sandboxed vault + alerts
├── domain/
│   ├── entities/
│   │   ├── document_type.dart                  # Fuel QR, Insurance, License, Custom
│   │   ├── sync_status.dart                    # Synced, Queued, Downloading, Failed
│   │   └── vehicle_document.dart               # Core immutable domain model
│   └── repositories/
│       ├── i_sync_queue_repository.dart
│       └── i_vehicle_document_repository.dart
└── presentation/
    ├── controllers/document_providers.dart     # Riverpod reactive dependency injection
    └── screens/
        ├── document_list_screen.dart           # Offline catalog with live sync bar
        └── document_viewer_screen.dart         # Native viewer with auto-brightness
```

---

## Setup & Configuration Guide

### 1. Drift Code Generation
To generate the Drift SQLite database code:
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 2. Google Cloud Console (OAuth 2.0 AppData Scope)
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Enable the **Google Drive API**.
3. In **OAuth Consent Screen**, add the scope:
   - `https://www.googleapis.com/auth/drive.appdata`
4. Create **OAuth 2.0 Client IDs**:
   - **Android:** Add your Package Name (e.g. `com.example.vehicle_document_vault`) and SHA-1 certificate fingerprint.
   - **iOS:** Add your iOS Bundle ID and configure `GoogleService-Info.plist`.

### 3. Android Configuration
In `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### 4. iOS Configuration
In `ios/Runner/Info.plist`:
```xml
<!-- Screen Brightness -->
<key>UIFileSharingEnabled</key>
<false/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<false/>

<!-- Google Sign-In URL Schemes -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>YOUR_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

---

## Running Automated Verification
```bash
flutter test
```
