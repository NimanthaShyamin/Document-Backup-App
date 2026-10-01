import 'package:flutter/material.dart';

/// Represents a dynamic document category in the Universal AI Document Vault.
class DocumentCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color? color;
  final bool isSystem;

  const DocumentCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.color,
    this.isSystem = true,
  });

  /// Universal system preset categories covering personal, vehicle, finance, travel, and general.
  static const List<DocumentCategory> systemPresets = [
    DocumentCategory(
      id: 'id_card',
      name: 'National ID / Passport',
      icon: Icons.badge_outlined,
      color: Color(0xFF8B5CF6),
    ),
    DocumentCategory(
      id: 'driving_license',
      name: 'Driving License',
      icon: Icons.credit_card_outlined,
      color: Color(0xFF6366F1),
    ),
    DocumentCategory(
      id: 'vehicle',
      name: 'Vehicles & Transport',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF2563EB),
    ),
    DocumentCategory(
      id: 'bill',
      name: 'Invoice / Bill / Tax',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF10B981),
    ),
    DocumentCategory(
      id: 'e_ticket',
      name: 'Travel & E-Tickets',
      icon: Icons.confirmation_number_outlined,
      color: Color(0xFF0EA5E9),
    ),
    DocumentCategory(
      id: 'certificate',
      name: 'Certificate & Education',
      icon: Icons.verified_user_outlined,
      color: Color(0xFFF59E0B),
    ),
    DocumentCategory(
      id: 'insurance_card',
      name: 'Insurance Policy',
      icon: Icons.security,
      color: Color(0xFF3B82F6),
    ),
    DocumentCategory(
      id: 'revenue_license',
      name: 'Revenue License',
      icon: Icons.description_outlined,
      color: Color(0xFF14B8A6),
    ),
    DocumentCategory(
      id: 'fuel_qr',
      name: 'Fuel Pass QR',
      icon: Icons.qr_code_2,
      color: Color(0xFFEC4899),
    ),
    DocumentCategory(
      id: 'general',
      name: 'General Document',
      icon: Icons.folder_shared_outlined,
      color: Color(0xFF64748B),
    ),
  ];

  /// Resolves an input string or legacy enum key to a matching preset or dynamic category.
  static DocumentCategory resolve(String? rawCategory) {
    if (rawCategory == null || rawCategory.trim().isEmpty) {
      return systemPresets.last; // General
    }
    final clean = rawCategory.trim();
    final normalized = clean.toLowerCase().replaceAll(' ', '_');

    for (final preset in systemPresets) {
      if (preset.id == normalized ||
          preset.name.toLowerCase() == clean.toLowerCase() ||
          preset.id.replaceAll('_', '') == normalized.replaceAll('_', '')) {
        return preset;
      }
    }

    return DocumentCategory(
      id: normalized,
      name: clean,
      icon: Icons.folder_outlined,
      color: const Color(0xFF3B82F6),
      isSystem: false,
    );
  }
}
