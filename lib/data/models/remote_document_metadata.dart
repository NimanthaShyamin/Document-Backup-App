import 'package:googleapis/drive/v3.dart' as drive;

/// Parsed metadata from a Google Drive AppData file including custom appProperties.
class RemoteDocumentMetadata {
  final String driveFileId;
  final String name;
  final String documentId;
  final String documentType;
  final String vehicleRegNo;
  final String? policyNo;
  final DateTime? expiryDate;
  final String checksumSha256;
  final DateTime clientModified;
  final DateTime? driveModifiedTime;
  final int? sizeBytes;

  const RemoteDocumentMetadata({
    required this.driveFileId,
    required this.name,
    required this.documentId,
    required this.documentType,
    required this.vehicleRegNo,
    this.policyNo,
    this.expiryDate,
    required this.checksumSha256,
    required this.clientModified,
    this.driveModifiedTime,
    this.sizeBytes,
  });

  static RemoteDocumentMetadata? fromDriveFile(drive.File file) {
    if (file.id == null || file.name == null) return null;

    final props = file.appProperties ?? {};
    final docId = props['document_id'] ?? file.name!.split('.').first;
    final docType = props['document_type'] ?? 'custom';
    final regNo = props['vehicle_reg_no'] ?? 'UNKNOWN';
    final policy = props['policy_no'];
    final expiryEpoch = int.tryParse(props['expiry_date'] ?? '');
    final checksum = props['checksum_sha256'] ?? file.md5Checksum ?? '';
    final clientModEpoch = int.tryParse(props['client_modified'] ?? '');

    return RemoteDocumentMetadata(
      driveFileId: file.id!,
      name: file.name!,
      documentId: docId,
      documentType: docType,
      vehicleRegNo: regNo,
      policyNo: policy?.isNotEmpty == true ? policy : null,
      expiryDate: expiryEpoch != null ? DateTime.fromMillisecondsSinceEpoch(expiryEpoch) : null,
      checksumSha256: checksum,
      clientModified: clientModEpoch != null
          ? DateTime.fromMillisecondsSinceEpoch(clientModEpoch)
          : (file.modifiedTime ?? DateTime.now()),
      driveModifiedTime: file.modifiedTime,
      sizeBytes: file.size != null ? int.tryParse(file.size!) : null,
    );
  }
}
