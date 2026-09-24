import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Table representing local sandboxed vehicle documents.
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
  int get schemaVersion => 1;

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
      );
}
