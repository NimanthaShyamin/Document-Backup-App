import 'dart:io';
import '../entities/document_type.dart';
import '../entities/vehicle_document.dart';

/// Contract for vehicle document storage, retrieval, and reactive watching.
abstract class IVehicleDocumentRepository {
  /// Continuous reactive stream of all local documents directly from SQLite WAL cache.
  Stream<List<VehicleDocument>> watchAllDocuments();

  /// Fetches a single document by UUID.
  Future<VehicleDocument?> getDocumentById(String id);

  /// Saves or updates a document locally, copies to sandboxed vault, schedules alerts, and enqueues sync.
  Future<VehicleDocument> saveDocument({
    String? existingId,
    required DocumentType documentType,
    required String title,
    required String vehicleRegNo,
    String? policyNo,
    DateTime? expiryDate,
    required File sourceFile,
  });

  /// Deletes a document locally and enqueues cloud deletion.
  Future<void> deleteDocument(String id);
}
