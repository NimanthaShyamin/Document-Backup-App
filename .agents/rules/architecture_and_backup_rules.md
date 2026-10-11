# Architecture, Sync & AI Invariant Rules

Please refer to the primary rules specification in [AGENTS.md](file:///c:/Users/RaMoVEd/my/Github/Document-Backup-App/AGENTS.md) at the repository root.

Summary of Invariants:
1. Cloud backup strictly precedes Gemini AI extraction. AI scan pauses in `ScanStatus.waitingBackup` while backup is syncing or pending.
2. SQLite uses WAL journal mode and 10000ms busy timeout (`PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 10000;`).
3. WorkManager rescan worker uses static constant name `com.vehicledocs.ai_rescan_worker` with `ExistingWorkPolicy.keep`.
4. Google Drive network operations use a 60-second timeout with exponential retry on `DriveSyncException`.
5. Recycle Bin documents (`isDeleted == true`) are excluded from backup upload, sync download, and AI scan.
6. Bottom sheets wrap content in `Material(color: Colors.transparent)` to satisfy Material ancestor assertions.
7. Any future modifications must pass `flutter analyze` and `flutter test`.
