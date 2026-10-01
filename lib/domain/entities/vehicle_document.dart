import 'document_type.dart';
import 'sync_status.dart';

/// Core domain entity representing an authenticated, sandboxed document
/// in the Universal AI Document Vault.
class VehicleDocument {
  final String id;
  final DocumentType documentType;
  final String category; // Universal dynamic category identifier or display name
  final String title;
  final String vehicleRegNo; // Retained for backwards compatibility
  final String? policyNo; // Retained for backwards compatibility
  final DateTime? expiryDate;
  final String localFilePath;
  final String? driveFileId;
  final String fileChecksumSha256;
  final SyncStatus syncStatus;
  final DateTime lastModifiedTimestamp;
  final DateTime createdAt;
  final Map<String, dynamic> visibleFields; // Dynamic UI fields
  final String? hiddenContext; // Silent AI context & deep extracted text
  final bool requiresAiScan; // Flag indicating if document needs AI extraction

  const VehicleDocument({
    required this.id,
    required this.documentType,
    this.category = 'General',
    required this.title,
    required this.vehicleRegNo,
    this.policyNo,
    this.expiryDate,
    required this.localFilePath,
    this.driveFileId,
    required this.fileChecksumSha256,
    required this.syncStatus,
    required this.lastModifiedTimestamp,
    required this.createdAt,
    this.visibleFields = const {},
    this.hiddenContext,
    this.requiresAiScan = false,
  });

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  VehicleDocument copyWith({
    String? id,
    DocumentType? documentType,
    String? category,
    String? title,
    String? vehicleRegNo,
    String? policyNo,
    DateTime? expiryDate,
    String? localFilePath,
    String? driveFileId,
    String? fileChecksumSha256,
    SyncStatus? syncStatus,
    DateTime? lastModifiedTimestamp,
    DateTime? createdAt,
    Map<String, dynamic>? visibleFields,
    String? hiddenContext,
    bool? requiresAiScan,
  }) {
    return VehicleDocument(
      id: id ?? this.id,
      documentType: documentType ?? this.documentType,
      category: category ?? this.category,
      title: title ?? this.title,
      vehicleRegNo: vehicleRegNo ?? this.vehicleRegNo,
      policyNo: policyNo ?? this.policyNo,
      expiryDate: expiryDate ?? this.expiryDate,
      localFilePath: localFilePath ?? this.localFilePath,
      driveFileId: driveFileId ?? this.driveFileId,
      fileChecksumSha256: fileChecksumSha256 ?? this.fileChecksumSha256,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModifiedTimestamp: lastModifiedTimestamp ?? this.lastModifiedTimestamp,
      createdAt: createdAt ?? this.createdAt,
      visibleFields: visibleFields ?? this.visibleFields,
      hiddenContext: hiddenContext ?? this.hiddenContext,
      requiresAiScan: requiresAiScan ?? this.requiresAiScan,
    );
  }
}
