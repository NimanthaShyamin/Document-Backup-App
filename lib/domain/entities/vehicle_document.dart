import 'document_type.dart';
import 'sync_status.dart';

/// Core domain entity representing an authenticated, sandboxed vehicle document.
class VehicleDocument {
  final String id;
  final DocumentType documentType;
  final String title;
  final String vehicleRegNo;
  final String? policyNo;
  final DateTime? expiryDate;
  final String localFilePath;
  final String? driveFileId;
  final String fileChecksumSha256;
  final SyncStatus syncStatus;
  final DateTime lastModifiedTimestamp;
  final DateTime createdAt;

  const VehicleDocument({
    required this.id,
    required this.documentType,
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
  });

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  VehicleDocument copyWith({
    String? id,
    DocumentType? documentType,
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
  }) {
    return VehicleDocument(
      id: id ?? this.id,
      documentType: documentType ?? this.documentType,
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
    );
  }
}
