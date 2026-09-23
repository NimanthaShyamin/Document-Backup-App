import 'package:flutter/material.dart';

/// Supported vehicle document categories.
enum DocumentType {
  fuelQr('fuel_qr', 'Fuel Pass QR', Icons.qr_code_2),
  insuranceCard('insurance_card', 'Motor Insurance Certificate', Icons.security),
  revenueLicense('revenue_license', 'Vehicle Revenue License', Icons.description),
  custom('custom', 'Vehicle Document', Icons.folder_shared);

  final String value;
  final String label;
  final IconData icon;

  const DocumentType(this.value, this.label, this.icon);

  static DocumentType fromString(String val) {
    return DocumentType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => DocumentType.custom,
    );
  }
}
