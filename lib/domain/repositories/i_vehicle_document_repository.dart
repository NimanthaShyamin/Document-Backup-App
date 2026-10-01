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

  /// Deletes a document locally and enqueues cloud deletion.
  Future<void> deleteDocument(String id);
}
