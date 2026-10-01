import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Table representing local sandboxed documents in the Universal AI Document Vault.
@DataClassName('VehicleDocumentData')
class VehicleDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get documentType => text()();
  TextColumn get title => text()();
  TextColumn get vehicleRegNo => text()();
  TextColumn get policyNo => text().nullable()();
  IntColumn get expiryDate => integer().nullable()();
  TextColumn get localFilePath => text()();
  TextColumn get driveFileId => text().nullable()();
  TextColumn get fileChecksumSha256 => text()();
  TextColumn get syncStatus => text()();
  IntColumn get lastModifiedTimestamp => integer()();
  IntColumn get createdAt => integer()();

  // Phase 1 Schema Expansion for Universal AI Document Vault
  TextColumn get category => text().withDefault(const Constant('General'))();
  TextColumn get visibleFields => text().withDefault(const Constant('{}'))();
  TextColumn get hiddenContext => text().nullable()();
  BoolColumn get requiresAiScan => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table representing the FIFO synchronization queue for offline-to-cloud sync.
@DataClassName('SyncQueueData')
class SyncQueue extends Table {
  IntColumn get queueId => integer().autoIncrement()();
  TextColumn get documentId => text()();
  TextColumn get action => text()(); // 'upload' | 'delete' | 'download'
  TextColumn get driveFileId => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get lastAttempt => integer().nullable()();
  IntColumn get nextRetryAt => integer()();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get createdAt => integer()();
}

@DriftDatabase(tables: [VehicleDocuments, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 2;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'vehicle_documents_vault',
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // 1. Add new columns to existing table
            await m.addColumn(vehicleDocuments, vehicleDocuments.category);
            await m.addColumn(vehicleDocuments, vehicleDocuments.visibleFields);
            await m.addColumn(vehicleDocuments, vehicleDocuments.hiddenContext);
            await m.addColumn(vehicleDocuments, vehicleDocuments.requiresAiScan);

            // 2. Backfill category from existing document_type
            await customStatement(
              "UPDATE vehicle_documents SET category = document_type WHERE category IS NULL OR category = 'General';",
            );

            // 3. Migrate legacy vehicle_reg_no and policy_no into visible_fields JSON
            await customStatement('''
              UPDATE vehicle_documents 
              SET visible_fields = json_object(
                'vehicleRegNo', vehicle_reg_no,
                'policyNo', policy_no
              )
              WHERE vehicle_reg_no IS NOT NULL AND vehicle_reg_no != '' AND vehicle_reg_no != 'General';
            ''');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );
}
