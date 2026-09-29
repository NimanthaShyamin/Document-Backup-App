import 'package:flutter/material.dart';

/// Supported vehicle document categories.
enum DocumentType {
  fuelQr('fuel_qr', 'Fuel Pass QR', Icons.qr_code_2),
  insuranceCard('insurance_card', 'Motor Insurance Certificate', Icons.security),
  revenueLicense('revenue_license', 'Vehicle Revenue License', Icons.description),
  idCard('id_card', 'National ID / Passport', Icons.badge_outlined),
  drivingLicense('driving_license', 'Driving License', Icons.credit_card_outlined),
  eTicket('e_ticket', 'E-Ticket / Booking', Icons.confirmation_number_outlined),
  bill('bill', 'Invoice / Bill', Icons.receipt_long_outlined),
  certificate('certificate', 'Certificate / Medical', Icons.verified_user_outlined),
  custom('custom', 'General Document', Icons.folder_shared);

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
