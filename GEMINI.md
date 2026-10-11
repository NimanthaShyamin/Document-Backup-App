# Vehicle Document Vault - Agent Rules & Architecture Invariants

See the complete rules document in [AGENTS.md](file:///c:/Users/RaMoVEd/my/Github/Document-Backup-App/AGENTS.md).

## Critical Invariants:
1. **Cloud Backup Priority**: Google Drive AppData sync strictly precedes Gemini AI scanning. AI scans pause in `ScanStatus.waitingBackup` whenever backup is syncing or documents are pending upload.
2. **SQLite WAL & Busy Timeout**: Always retain `PRAGMA journal_mode = WAL;` and `PRAGMA busy_timeout = 10000;` in `AppDatabase.beforeOpen`.
3. **Fixed WorkManager Task Name**: Always use `com.vehicledocs.ai_rescan_worker` with `ExistingWorkPolicy.keep`.
4. **Drive Request Timeout**: Minimum 60-second timeout on Drive operations with exponential backoff on `DriveSyncException`.
5. **Soft-Deleted Document Guard**: `isDeleted == true` documents must never be uploaded, downloaded, or scanned.
6. **Material Widget Discipline**: Bottom sheets must wrap tiles with `Material(color: Colors.transparent)`.
7. **Validation**: All changes must pass `flutter analyze` and `flutter test`.
8. **Extraction Prompt Discipline**: The Gemini prompt must retain the unified JSON schema while enforcing visual fallback for photos, contextual warranty calculations, and Sri Lankan plate normalization.
