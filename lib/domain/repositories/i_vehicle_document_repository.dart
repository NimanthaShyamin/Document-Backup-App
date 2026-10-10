import 'dart:io';
import '../entities/document_type.dart';
import '../entities/vehicle_document.dart';

/// Contract for document storage, retrieval, and reactive watching in the Universal Vault.
abstract class IVehicleDocumentRepository {
  /// Continuous reactive stream of all local documents directly from SQLite WAL cache.
  Stream<List<VehicleDocument>> watchAllDocuments();

  /// Fetches a single document by UUID.
  Future<VehicleDocument?> getDocumentById(String id);

  /// Saves or updates a document locally, copies to sandboxed vault, schedules alerts, and enqueues sync.
  Future<VehicleDocument> saveDocument({
    String? existingId,
    DocumentType? documentType,
    String? category,
    required String title,
    String? vehicleRegNo,
    String? policyNo,
    DateTime? expiryDate,
    Map<String, dynamic> visibleFields = const {},
    String? hiddenContext,
    bool requiresAiScan = false,
    required File sourceFile,
  });

  /// Deletes a document locally (soft-delete into Recycle Bin) and enqueues sync.
  Future<void> deleteDocument(String id);

  /// Continuous reactive stream of documents currently in the Recycle Bin.
  Stream<List<VehicleDocument>> watchRecycleBinDocuments();

  /// Moves a document into the Recycle Bin (soft delete).
  Future<void> moveToRecycleBin(String id);

  /// Restores a document from the Recycle Bin back to the active vault.
  Future<void> restoreFromRecycleBin(String id);

  /// Permanently removes a document from vault, database, and cloud storage.
  Future<void> permanentlyDeleteDocument(String id);

  /// Permanently removes all documents currently in the Recycle Bin.
  Future<void> emptyRecycleBin();

  /// Automatically purges documents in the Recycle Bin older than retentionDays.
  Future<void> autoCleanupRecycleBin(int retentionDays);
}
