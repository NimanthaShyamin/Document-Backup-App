# Vehicle Document Vault - Architecture, Sync & AI Invariant Rules

> **CRITICAL CODEBASE INVARIANTS**: This document defines the non-negotiable architectural guarantees, concurrency contracts, and priority rules established as of commit `18455da` ("Main Fixed Version 02"). Any future feature, refactor, or bug fix **MUST** uphold and update these rules without regression.

---

## 1. Priority Invariant: Cloud Backup Strictly Precedes AI Extraction

### Rule
**Cloud Backup to Google Drive AppData (`SyncRepository`) ALWAYS has higher priority than Gemini AI scanning (`ForegroundScannerService` and `AiRescanWorker`).**

### Why
When offline documents are imported and the device reconnects to the internet, preserving user documents safely in the cloud is the primary promise. AI metadata extraction is an enrichment process that uploads heavy files to Gemini API. Running both concurrently causes SQLite file locks (`SqliteException(5)`), bandwidth saturation, upload timeouts, and data sync corruption.

### Implementation Requirements
1. **Foreground Scanner Gating** (`lib/presentation/controllers/foreground_scanner_service.dart`):
   - `ScanStatus` enum MUST include `waitingBackup`.
   - When `syncEngineStateProvider` is `SyncEngineSyncing` or `SyncRepository.isReconciling` is `true`:
     - Scanner state MUST transition to `ScanStatus.waitingBackup`.
     - Global countdown timers MUST be stopped (`_stopGlobalTimer()`).
     - `getWaitSecondsFor(docId)` MUST return `null` so countdown badges remain dormant.
   - When documents in SQLite have `syncStatus in ['pending_upload', 'queued_upload']` and the user is authenticated to Google Drive:
     - Scanner MUST pause in `ScanStatus.waitingBackup`, trigger `syncRepo.reconcileStartupDelta()`, and yield until cloud reconciliation reaches `SyncEngineIdle` or `SyncEngineFailed`.
   - When backup finishes (`SyncEngineIdle` or `SyncEngineFailed`), the queue resumes sequentially.
2. **Background Worker Gating** (`lib/data/datasources/remote/ai_rescan_worker.dart`):
   - `executeWorker()` MUST inspect `db.syncQueue` for pending `upload` tasks before scanning.
   - If pending upload tasks exist:
     - Log deferral: `[AiRescanWorker] Found X upload task(s) in sync queue. Deferring AI scan.`
     - Reschedule rescan with `Duration(seconds: 30)`.
     - Exit cleanly with `return true;` to avoid aggressive WorkManager error retries.
3. **UI Badge Reflection** (`lib/presentation/widgets/pending_ai_scan_badge.dart`):
   - When `scanState.status == ScanStatus.waitingBackup`:
     - Display text: `"Waiting for Backup"`.
     - Icon: `Icons.cloud_upload_outlined`.
     - No countdown timer digits may be rendered.

---

## 2. Database Concurrency & Lock Prevention (`SqliteException(5)`)

### Rule
**SQLite MUST always operate in Write-Ahead Logging (WAL) mode with an active busy timeout.**

### Why
Default SQLite rollback journal (`DELETE`) with 0ms `busy_timeout` causes immediate database locking (`SqliteException(5): database is locked`) whenever a background isolate (WorkManager sync or rescan worker) and the main Flutter UI isolate access Drift at the same time.

### Implementation Requirements
1. In `lib/data/datasources/local/app_database.dart`:
   - `beforeOpen` callback MUST execute:
     ```dart
     await customStatement('PRAGMA journal_mode = WAL;');
     await customStatement('PRAGMA busy_timeout = 10000;');
     ```
   - NEVER revert to rollback journal mode.
2. In background isolates (`callbackDispatcher` in `main.dart`, `AiRescanWorker.executeWorker`):
   - If an isolate creates an owned `AppDatabase()` instance (`ownsDb`), it MUST close the connection in a `finally` block or before returning (`await db.close()`).

---

## 3. Rate Limiting & WorkManager Task Flooding Prevention

### Rule
**Strictly adhere to Gemini API free-tier quotas (1 document per 60-second cooldown in foreground, 1 document per worker execution). NEVER dynamically generate WorkManager task names.**

### Why
Registering tasks with dynamic names (e.g. `ai_rescan_${DateTime.now()}`) floods Android WorkManager with 8+ concurrent worker jobs upon network reconnection, exhausting device memory, spinning battery, and hitting Google AI Studio 429 quota limits.

### Implementation Requirements
1. In `lib/data/datasources/remote/ai_rescan_worker.dart`:
   - The task registration MUST use a single static constant task name:
     ```dart
     static const String rescanUniqueWorkName = 'com.vehicledocs.ai_rescan_worker';
     ```
   - Use `existingWorkPolicy: ExistingWorkPolicy.keep` to prevent duplicate task registrations.
   - `executeWorker()` processes **strictly ONE document** per run, then schedules the next run with a 60-second delay if more documents remain pending.
2. In `lib/presentation/controllers/foreground_scanner_service.dart`:
   - 1st imported document scans with 0s delay.
   - 2nd document starts a 60-second rate-limit countdown.
   - Subsequent documents calculate delay as `baseSecondsRemaining + (index * 60)`.
   - When offline, all countdown timers stop immediately and resume only when back online and cloud backup is complete.

---

## 4. Google Drive Network Resilience & Timeout Handling

### Rule
**File transfers to Google Drive AppData MUST use at least 60-second timeouts and automatic transient retry with exponential backoff.**

### Why
Camera photos and multi-page vehicle insurance PDFs can range from 2MB to 15MB. On 3G/4G cellular connections, a 30-second timeout causes premature `DriveSyncException` timeouts.

### Implementation Requirements
1. In `lib/data/datasources/remote/drive_sync_service.dart`:
   - Drive API action timeout MUST be set to `Duration(seconds: 60)`.
   - `_executeWithRetry` MUST catch:
     - `drive.DetailedApiRequestError` (401 token refresh, 429/403/5xx backoff)
     - `SocketException`
     - `http.ClientException`
     - `TimeoutException`
     - `DriveAuthException`
     - `DriveSyncException` (with exponential backoff `1000 * 2^(attempts - 1)` ms)
2. In `lib/data/repositories/sync_repository.dart`:
   - Connectivity listener MUST debounce by 1000ms:
     ```dart
     _syncStateController.add(const SyncEngineState.syncing(progress: 0.0, currentAction: 'Connecting to cloud vault...'));
     ```
   - Automatically retry silent authentication 3 times with 2-second delays on network reconnection before declaring unauthenticated.
   - Queue task failures in `_handleQueueTaskFailure` MUST be wrapped in try-catch and schedule automated retry timers.

---

## 5. Soft Delete & Recycle Bin Integrity

### Rule
**Documents soft-deleted into the Recycle Bin (`isDeleted == true`) MUST NEVER be uploaded to Google Drive, downloaded from Drive AppData, or processed by AI scanning.**

### Implementation Requirements
1. In `lib/data/repositories/sync_repository.dart`:
   - `_uploadAllPendingDocuments`: Query MUST filter `& t.isDeleted.equals(false)` and loop check `if (doc.isDeleted) continue;`.
   - `_executeQueueTask`: In case `'upload'`, verify `if (doc == null || doc.isDeleted) return;`.
   - `reconcile`: Cloud files corresponding to documents currently in Recycle Bin MUST NOT be re-downloaded or resurrected.
2. In `lib/data/datasources/remote/ai_rescan_worker.dart`:
   - Query MUST filter `& t.isDeleted.equals(false)`.
3. In `lib/presentation/controllers/foreground_scanner_service.dart`:
   - Query MUST filter `& t.isDeleted.equals(false)`.

---

## 6. UI & Material Framework Compliance

### Rule
**All interactive components and modal sheets MUST adhere to Flutter Material guidelines and avoid assertion errors.**

### Implementation Requirements
1. Modal bottom sheets containing `ListTile`, ink splashes, or clickable buttons MUST be wrapped in a transparent `Material` widget:
   ```dart
   Material(
     color: Colors.transparent,
     child: Column(...),
   )
   ```
2. Android manifest:
   - Do NOT re-add deprecated `io.flutter.embedding.android.EnableImpeller` in `android/app/src/main/AndroidManifest.xml`.
   - Impeller management is handled automatically by the Flutter engine.

---

## 7. Change Validation & Rule Maintenance Protocol

Whenever modifying the codebase or adding new features:
1. **Verify No Regression**:
   - Run `flutter analyze` — MUST report **No issues found!** (0 errors, 0 warnings).
   - Run `flutter test` — ALL unit and widget tests MUST pass.
2. **Update Rules When Adding Features**:
   - If adding a new background worker, sync target (e.g. OneDrive, Dropbox), or AI provider (e.g. Claude, OpenAI), update this document with its respective concurrency and rate-limiting invariants.
   - Never remove existing safeguards without explicit user approval.

---

## 8. Gemini Document Extraction Prompt Invariants

### Rule
**The Gemini system prompt in `GeminiDocumentExtractionService` must preserve the unified JSON schema and strictly enforce visual fallback, date arithmetic for warranties, and Sri Lankan vehicle registration normalization.**

### Implementation Requirements
1. **Visual Fallback for General Photos**:
   - Non-document photographs (landscapes, people, pets, items) without text must NOT fail or yield empty/null metadata.
   - Categorize as `"photo"` or `"image"`.
   - Set `"title"` to a brief descriptive topic (e.g. `"Photo of a Sunset"`).
   - Set `"expiry_date"` to `null` and keep `"dynamic_visible_fields"` minimal/empty.
   - Place full scene description in `"hidden_context"`.
2. **Date Arithmetic & Warranty Calculation**:
   - Never blindly copy invoice "Due Date" as the expiry date.
   - Calculate actual warranty expiration: `Purchase Date + Warranty Duration = expiry_date`.
   - Secondary warranties (e.g. 1050 days service warranty) must be calculated and added to `"dynamic_visible_fields"` (e.g. `{"label": "Service Warranty Expiry", "value": "YYYY-MM-DD"}`).
3. **Sri Lankan Vehicle Registration Normalization**:
   - Recognize 2-letter province prefixes (`WP`, `SP`, `NP`, `CP`, `EP`, `NW`, `NC`, `SG`, `UP`).
   - Extract core vehicle registration cleanly (e.g. `"CAB-1234"`) and note province separately in visible fields.
   - Include both the core number and province-prefixed variants in `"hidden_context"` for seamless search indexing.
4. **Smart Draft Reconciliation & Error Re-Correction**:
   - When documents are imported offline with tentative metadata, Gemini is passed the draft details (`userDraftTitle`, `userDraftCategory`, `userDraftExpiryDate`).
   - Discard gibberish, meaningless (e.g. `"ttttt"`, `"aaaa"`), or placeholder titles and recreate a brand new compatible title based strictly on document content.
   - For matching/relevant user titles, enhance them with missing details (e.g. `"Student ID"` -> `"Student Identity Card - University of Colombo"`).
   - Re-correct mismatched categories to the true category.
   - Clear erroneous user expiry dates when documents do not expire (`expiry_date: null`).
5. **Non-Document / Photograph Visual Fallback with Offline Drafts**:
   - When an offline-imported image is a photograph without text (such as a portrait, person, animal, item, or scenery), user-entered offline draft metadata (e.g. category `"driving_license"`, title `"test 01"`, dummy expiry dates) must be identified as an offline placeholder/mistake and discarded.
   - Re-categorize to `"photo"`, generate a descriptive visual title (e.g. `"Portrait of a Professional Man"`), clear `expiry_date` to `null`, set `dynamic_visible_fields` to `[]`, and clear fake vehicle/policy numbers.
   - `ExtractedDocumentDetails.hasAnyDetail` must recognize `hiddenContext` so pure visual scene descriptions are accepted.
   - Multimodal photo extractions must utilize at least 45-second SDK timeouts and 90-second outer pipeline timeouts to prevent false retry exhaustion on high-resolution camera uploads.

---

## 9. Offline Import UI Discipline & API Key Redaction

### Rule
**Never run AI scan spinners or attempt network connections when offline. Never leak private API keys or socket stack traces in the UI.**

### Implementation Requirements
1. In `lib/presentation/widgets/import_document_metadata_sheet.dart`:
   - Inspect offline status in `initState` and `_analyzeWithGemini()` using `foregroundScanStateProvider` and `Connectivity()`.
   - When offline, do NOT show "Analyzing document with Gemini AI..." spinner.
   - Display `"Offline Mode — Manual Entry"` banner with `Icons.cloud_off_rounded`.
   - Retain complete user editability so documents can be saved with `requiresAiScan = true`.
2. In `lib/data/datasources/remote/gemini_document_extraction_service.dart`:
   - `sanitizeErrorMessage()` must sanitize all error strings before returning in `ExtractedDocumentDetails.error`.
   - Strictly strip `key=[a-zA-Z0-9_\-]+` and replace with `key=[REDACTED]`.
   - Map `SocketException` / `ClientException with SocketException` to friendly offline messages.


