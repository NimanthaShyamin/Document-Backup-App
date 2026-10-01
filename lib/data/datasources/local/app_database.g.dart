// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $VehicleDocumentsTable extends VehicleDocuments
    with TableInfo<$VehicleDocumentsTable, VehicleDocumentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehicleDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _documentTypeMeta =
      const VerificationMeta('documentType');
  @override
  late final GeneratedColumn<String> documentType = GeneratedColumn<String>(
      'document_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _vehicleRegNoMeta =
      const VerificationMeta('vehicleRegNo');
  @override
  late final GeneratedColumn<String> vehicleRegNo = GeneratedColumn<String>(
      'vehicle_reg_no', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _policyNoMeta =
      const VerificationMeta('policyNo');
  @override
  late final GeneratedColumn<String> policyNo = GeneratedColumn<String>(
      'policy_no', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _expiryDateMeta =
      const VerificationMeta('expiryDate');
  @override
  late final GeneratedColumn<int> expiryDate = GeneratedColumn<int>(
      'expiry_date', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _localFilePathMeta =
      const VerificationMeta('localFilePath');
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
      'local_file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _driveFileIdMeta =
      const VerificationMeta('driveFileId');
  @override
  late final GeneratedColumn<String> driveFileId = GeneratedColumn<String>(
      'drive_file_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileChecksumSha256Meta =
      const VerificationMeta('fileChecksumSha256');
  @override
  late final GeneratedColumn<String> fileChecksumSha256 =
      GeneratedColumn<String>('file_checksum_sha256', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastModifiedTimestampMeta =
      const VerificationMeta('lastModifiedTimestamp');
  @override
  late final GeneratedColumn<int> lastModifiedTimestamp = GeneratedColumn<int>(
      'last_modified_timestamp', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('General'));
  static const VerificationMeta _visibleFieldsMeta =
      const VerificationMeta('visibleFields');
  @override
  late final GeneratedColumn<String> visibleFields = GeneratedColumn<String>(
      'visible_fields', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _hiddenContextMeta =
      const VerificationMeta('hiddenContext');
  @override
  late final GeneratedColumn<String> hiddenContext = GeneratedColumn<String>(
      'hidden_context', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _requiresAiScanMeta =
      const VerificationMeta('requiresAiScan');
  @override
  late final GeneratedColumn<bool> requiresAiScan = GeneratedColumn<bool>(
      'requires_ai_scan', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("requires_ai_scan" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        documentType,
        title,
        vehicleRegNo,
        policyNo,
        expiryDate,
        localFilePath,
        driveFileId,
        fileChecksumSha256,
        syncStatus,
        lastModifiedTimestamp,
        createdAt,
        category,
        visibleFields,
        hiddenContext,
        requiresAiScan
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicle_documents';
  @override
  VerificationContext validateIntegrity(
      Insertable<VehicleDocumentData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('document_type')) {
      context.handle(
          _documentTypeMeta,
          documentType.isAcceptableOrUnknown(
              data['document_type']!, _documentTypeMeta));
    } else if (isInserting) {
      context.missing(_documentTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('vehicle_reg_no')) {
      context.handle(
          _vehicleRegNoMeta,
          vehicleRegNo.isAcceptableOrUnknown(
              data['vehicle_reg_no']!, _vehicleRegNoMeta));
    } else if (isInserting) {
      context.missing(_vehicleRegNoMeta);
    }
    if (data.containsKey('policy_no')) {
      context.handle(_policyNoMeta,
          policyNo.isAcceptableOrUnknown(data['policy_no']!, _policyNoMeta));
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
          _expiryDateMeta,
          expiryDate.isAcceptableOrUnknown(
              data['expiry_date']!, _expiryDateMeta));
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
          _localFilePathMeta,
          localFilePath.isAcceptableOrUnknown(
              data['local_file_path']!, _localFilePathMeta));
    } else if (isInserting) {
      context.missing(_localFilePathMeta);
    }
    if (data.containsKey('drive_file_id')) {
      context.handle(
          _driveFileIdMeta,
          driveFileId.isAcceptableOrUnknown(
              data['drive_file_id']!, _driveFileIdMeta));
    }
    if (data.containsKey('file_checksum_sha256')) {
      context.handle(
          _fileChecksumSha256Meta,
          fileChecksumSha256.isAcceptableOrUnknown(
              data['file_checksum_sha256']!, _fileChecksumSha256Meta));
    } else if (isInserting) {
      context.missing(_fileChecksumSha256Meta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    } else if (isInserting) {
      context.missing(_syncStatusMeta);
    }
    if (data.containsKey('last_modified_timestamp')) {
      context.handle(
          _lastModifiedTimestampMeta,
          lastModifiedTimestamp.isAcceptableOrUnknown(
              data['last_modified_timestamp']!, _lastModifiedTimestampMeta));
    } else if (isInserting) {
      context.missing(_lastModifiedTimestampMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('visible_fields')) {
      context.handle(
          _visibleFieldsMeta,
          visibleFields.isAcceptableOrUnknown(
              data['visible_fields']!, _visibleFieldsMeta));
    }
    if (data.containsKey('hidden_context')) {
      context.handle(
          _hiddenContextMeta,
          hiddenContext.isAcceptableOrUnknown(
              data['hidden_context']!, _hiddenContextMeta));
    }
    if (data.containsKey('requires_ai_scan')) {
      context.handle(
          _requiresAiScanMeta,
          requiresAiScan.isAcceptableOrUnknown(
              data['requires_ai_scan']!, _requiresAiScanMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VehicleDocumentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VehicleDocumentData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      documentType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}document_type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      vehicleRegNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vehicle_reg_no'])!,
      policyNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}policy_no']),
      expiryDate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}expiry_date']),
      localFilePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_file_path'])!,
      driveFileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}drive_file_id']),
      fileChecksumSha256: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}file_checksum_sha256'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      lastModifiedTimestamp: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}last_modified_timestamp'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      visibleFields: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}visible_fields'])!,
      hiddenContext: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hidden_context']),
      requiresAiScan: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}requires_ai_scan'])!,
    );
  }

  @override
  $VehicleDocumentsTable createAlias(String alias) {
    return $VehicleDocumentsTable(attachedDatabase, alias);
  }
}

class VehicleDocumentData extends DataClass
    implements Insertable<VehicleDocumentData> {
  final String id;
  final String documentType;
  final String title;
  final String vehicleRegNo;
  final String? policyNo;
  final int? expiryDate;
  final String localFilePath;
  final String? driveFileId;
  final String fileChecksumSha256;
  final String syncStatus;
  final int lastModifiedTimestamp;
  final int createdAt;
  final String category;
  final String visibleFields;
  final String? hiddenContext;
  final bool requiresAiScan;
  const VehicleDocumentData(
      {required this.id,
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
      required this.category,
      required this.visibleFields,
      this.hiddenContext,
      required this.requiresAiScan});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_type'] = Variable<String>(documentType);
    map['title'] = Variable<String>(title);
    map['vehicle_reg_no'] = Variable<String>(vehicleRegNo);
    if (!nullToAbsent || policyNo != null) {
      map['policy_no'] = Variable<String>(policyNo);
    }
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<int>(expiryDate);
    }
    map['local_file_path'] = Variable<String>(localFilePath);
    if (!nullToAbsent || driveFileId != null) {
      map['drive_file_id'] = Variable<String>(driveFileId);
    }
    map['file_checksum_sha256'] = Variable<String>(fileChecksumSha256);
    map['sync_status'] = Variable<String>(syncStatus);
    map['last_modified_timestamp'] = Variable<int>(lastModifiedTimestamp);
    map['created_at'] = Variable<int>(createdAt);
    map['category'] = Variable<String>(category);
    map['visible_fields'] = Variable<String>(visibleFields);
    if (!nullToAbsent || hiddenContext != null) {
      map['hidden_context'] = Variable<String>(hiddenContext);
    }
    map['requires_ai_scan'] = Variable<bool>(requiresAiScan);
    return map;
  }

  VehicleDocumentsCompanion toCompanion(bool nullToAbsent) {
    return VehicleDocumentsCompanion(
      id: Value(id),
      documentType: Value(documentType),
      title: Value(title),
      vehicleRegNo: Value(vehicleRegNo),
      policyNo: policyNo == null && nullToAbsent
          ? const Value.absent()
          : Value(policyNo),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      localFilePath: Value(localFilePath),
      driveFileId: driveFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(driveFileId),
      fileChecksumSha256: Value(fileChecksumSha256),
      syncStatus: Value(syncStatus),
      lastModifiedTimestamp: Value(lastModifiedTimestamp),
      createdAt: Value(createdAt),
      category: Value(category),
      visibleFields: Value(visibleFields),
      hiddenContext: hiddenContext == null && nullToAbsent
          ? const Value.absent()
          : Value(hiddenContext),
      requiresAiScan: Value(requiresAiScan),
    );
  }

  factory VehicleDocumentData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VehicleDocumentData(
      id: serializer.fromJson<String>(json['id']),
      documentType: serializer.fromJson<String>(json['documentType']),
      title: serializer.fromJson<String>(json['title']),
      vehicleRegNo: serializer.fromJson<String>(json['vehicleRegNo']),
      policyNo: serializer.fromJson<String?>(json['policyNo']),
      expiryDate: serializer.fromJson<int?>(json['expiryDate']),
      localFilePath: serializer.fromJson<String>(json['localFilePath']),
      driveFileId: serializer.fromJson<String?>(json['driveFileId']),
      fileChecksumSha256:
          serializer.fromJson<String>(json['fileChecksumSha256']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastModifiedTimestamp:
          serializer.fromJson<int>(json['lastModifiedTimestamp']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      category: serializer.fromJson<String>(json['category']),
      visibleFields: serializer.fromJson<String>(json['visibleFields']),
      hiddenContext: serializer.fromJson<String?>(json['hiddenContext']),
      requiresAiScan: serializer.fromJson<bool>(json['requiresAiScan']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentType': serializer.toJson<String>(documentType),
      'title': serializer.toJson<String>(title),
      'vehicleRegNo': serializer.toJson<String>(vehicleRegNo),
      'policyNo': serializer.toJson<String?>(policyNo),
      'expiryDate': serializer.toJson<int?>(expiryDate),
      'localFilePath': serializer.toJson<String>(localFilePath),
      'driveFileId': serializer.toJson<String?>(driveFileId),
      'fileChecksumSha256': serializer.toJson<String>(fileChecksumSha256),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastModifiedTimestamp': serializer.toJson<int>(lastModifiedTimestamp),
      'createdAt': serializer.toJson<int>(createdAt),
      'category': serializer.toJson<String>(category),
      'visibleFields': serializer.toJson<String>(visibleFields),
      'hiddenContext': serializer.toJson<String?>(hiddenContext),
      'requiresAiScan': serializer.toJson<bool>(requiresAiScan),
    };
  }

  VehicleDocumentData copyWith(
          {String? id,
          String? documentType,
          String? title,
          String? vehicleRegNo,
          Value<String?> policyNo = const Value.absent(),
          Value<int?> expiryDate = const Value.absent(),
          String? localFilePath,
          Value<String?> driveFileId = const Value.absent(),
          String? fileChecksumSha256,
          String? syncStatus,
          int? lastModifiedTimestamp,
          int? createdAt,
          String? category,
          String? visibleFields,
          Value<String?> hiddenContext = const Value.absent(),
          bool? requiresAiScan}) =>
      VehicleDocumentData(
        id: id ?? this.id,
        documentType: documentType ?? this.documentType,
        title: title ?? this.title,
        vehicleRegNo: vehicleRegNo ?? this.vehicleRegNo,
        policyNo: policyNo.present ? policyNo.value : this.policyNo,
        expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
        localFilePath: localFilePath ?? this.localFilePath,
        driveFileId: driveFileId.present ? driveFileId.value : this.driveFileId,
        fileChecksumSha256: fileChecksumSha256 ?? this.fileChecksumSha256,
        syncStatus: syncStatus ?? this.syncStatus,
        lastModifiedTimestamp:
            lastModifiedTimestamp ?? this.lastModifiedTimestamp,
        createdAt: createdAt ?? this.createdAt,
        category: category ?? this.category,
        visibleFields: visibleFields ?? this.visibleFields,
        hiddenContext:
            hiddenContext.present ? hiddenContext.value : this.hiddenContext,
        requiresAiScan: requiresAiScan ?? this.requiresAiScan,
      );
  VehicleDocumentData copyWithCompanion(VehicleDocumentsCompanion data) {
    return VehicleDocumentData(
      id: data.id.present ? data.id.value : this.id,
      documentType: data.documentType.present
          ? data.documentType.value
          : this.documentType,
      title: data.title.present ? data.title.value : this.title,
      vehicleRegNo: data.vehicleRegNo.present
          ? data.vehicleRegNo.value
          : this.vehicleRegNo,
      policyNo: data.policyNo.present ? data.policyNo.value : this.policyNo,
      expiryDate:
          data.expiryDate.present ? data.expiryDate.value : this.expiryDate,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      driveFileId:
          data.driveFileId.present ? data.driveFileId.value : this.driveFileId,
      fileChecksumSha256: data.fileChecksumSha256.present
          ? data.fileChecksumSha256.value
          : this.fileChecksumSha256,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      lastModifiedTimestamp: data.lastModifiedTimestamp.present
          ? data.lastModifiedTimestamp.value
          : this.lastModifiedTimestamp,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      category: data.category.present ? data.category.value : this.category,
      visibleFields: data.visibleFields.present
          ? data.visibleFields.value
          : this.visibleFields,
      hiddenContext: data.hiddenContext.present
          ? data.hiddenContext.value
          : this.hiddenContext,
      requiresAiScan: data.requiresAiScan.present
          ? data.requiresAiScan.value
          : this.requiresAiScan,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VehicleDocumentData(')
          ..write('id: $id, ')
          ..write('documentType: $documentType, ')
          ..write('title: $title, ')
          ..write('vehicleRegNo: $vehicleRegNo, ')
          ..write('policyNo: $policyNo, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('fileChecksumSha256: $fileChecksumSha256, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModifiedTimestamp: $lastModifiedTimestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('category: $category, ')
          ..write('visibleFields: $visibleFields, ')
          ..write('hiddenContext: $hiddenContext, ')
          ..write('requiresAiScan: $requiresAiScan')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      documentType,
      title,
      vehicleRegNo,
      policyNo,
      expiryDate,
      localFilePath,
      driveFileId,
      fileChecksumSha256,
      syncStatus,
      lastModifiedTimestamp,
      createdAt,
      category,
      visibleFields,
      hiddenContext,
      requiresAiScan);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleDocumentData &&
          other.id == this.id &&
          other.documentType == this.documentType &&
          other.title == this.title &&
          other.vehicleRegNo == this.vehicleRegNo &&
          other.policyNo == this.policyNo &&
          other.expiryDate == this.expiryDate &&
          other.localFilePath == this.localFilePath &&
          other.driveFileId == this.driveFileId &&
          other.fileChecksumSha256 == this.fileChecksumSha256 &&
          other.syncStatus == this.syncStatus &&
          other.lastModifiedTimestamp == this.lastModifiedTimestamp &&
          other.createdAt == this.createdAt &&
          other.category == this.category &&
          other.visibleFields == this.visibleFields &&
          other.hiddenContext == this.hiddenContext &&
          other.requiresAiScan == this.requiresAiScan);
}

class VehicleDocumentsCompanion extends UpdateCompanion<VehicleDocumentData> {
  final Value<String> id;
  final Value<String> documentType;
  final Value<String> title;
  final Value<String> vehicleRegNo;
  final Value<String?> policyNo;
  final Value<int?> expiryDate;
  final Value<String> localFilePath;
  final Value<String?> driveFileId;
  final Value<String> fileChecksumSha256;
  final Value<String> syncStatus;
  final Value<int> lastModifiedTimestamp;
  final Value<int> createdAt;
  final Value<String> category;
  final Value<String> visibleFields;
  final Value<String?> hiddenContext;
  final Value<bool> requiresAiScan;
  final Value<int> rowid;
  const VehicleDocumentsCompanion({
    this.id = const Value.absent(),
    this.documentType = const Value.absent(),
    this.title = const Value.absent(),
    this.vehicleRegNo = const Value.absent(),
    this.policyNo = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.driveFileId = const Value.absent(),
    this.fileChecksumSha256 = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastModifiedTimestamp = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.category = const Value.absent(),
    this.visibleFields = const Value.absent(),
    this.hiddenContext = const Value.absent(),
    this.requiresAiScan = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehicleDocumentsCompanion.insert({
    required String id,
    required String documentType,
    required String title,
    required String vehicleRegNo,
    this.policyNo = const Value.absent(),
    this.expiryDate = const Value.absent(),
    required String localFilePath,
    this.driveFileId = const Value.absent(),
    required String fileChecksumSha256,
    required String syncStatus,
    required int lastModifiedTimestamp,
    required int createdAt,
    this.category = const Value.absent(),
    this.visibleFields = const Value.absent(),
    this.hiddenContext = const Value.absent(),
    this.requiresAiScan = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        documentType = Value(documentType),
        title = Value(title),
        vehicleRegNo = Value(vehicleRegNo),
        localFilePath = Value(localFilePath),
        fileChecksumSha256 = Value(fileChecksumSha256),
        syncStatus = Value(syncStatus),
        lastModifiedTimestamp = Value(lastModifiedTimestamp),
        createdAt = Value(createdAt);
  static Insertable<VehicleDocumentData> custom({
    Expression<String>? id,
    Expression<String>? documentType,
    Expression<String>? title,
    Expression<String>? vehicleRegNo,
    Expression<String>? policyNo,
    Expression<int>? expiryDate,
    Expression<String>? localFilePath,
    Expression<String>? driveFileId,
    Expression<String>? fileChecksumSha256,
    Expression<String>? syncStatus,
    Expression<int>? lastModifiedTimestamp,
    Expression<int>? createdAt,
    Expression<String>? category,
    Expression<String>? visibleFields,
    Expression<String>? hiddenContext,
    Expression<bool>? requiresAiScan,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentType != null) 'document_type': documentType,
      if (title != null) 'title': title,
      if (vehicleRegNo != null) 'vehicle_reg_no': vehicleRegNo,
      if (policyNo != null) 'policy_no': policyNo,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (driveFileId != null) 'drive_file_id': driveFileId,
      if (fileChecksumSha256 != null)
        'file_checksum_sha256': fileChecksumSha256,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastModifiedTimestamp != null)
        'last_modified_timestamp': lastModifiedTimestamp,
      if (createdAt != null) 'created_at': createdAt,
      if (category != null) 'category': category,
      if (visibleFields != null) 'visible_fields': visibleFields,
      if (hiddenContext != null) 'hidden_context': hiddenContext,
      if (requiresAiScan != null) 'requires_ai_scan': requiresAiScan,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehicleDocumentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? documentType,
      Value<String>? title,
      Value<String>? vehicleRegNo,
      Value<String?>? policyNo,
      Value<int?>? expiryDate,
      Value<String>? localFilePath,
      Value<String?>? driveFileId,
      Value<String>? fileChecksumSha256,
      Value<String>? syncStatus,
      Value<int>? lastModifiedTimestamp,
      Value<int>? createdAt,
      Value<String>? category,
      Value<String>? visibleFields,
      Value<String?>? hiddenContext,
      Value<bool>? requiresAiScan,
      Value<int>? rowid}) {
    return VehicleDocumentsCompanion(
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
      lastModifiedTimestamp:
          lastModifiedTimestamp ?? this.lastModifiedTimestamp,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      visibleFields: visibleFields ?? this.visibleFields,
      hiddenContext: hiddenContext ?? this.hiddenContext,
      requiresAiScan: requiresAiScan ?? this.requiresAiScan,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentType.present) {
      map['document_type'] = Variable<String>(documentType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (vehicleRegNo.present) {
      map['vehicle_reg_no'] = Variable<String>(vehicleRegNo.value);
    }
    if (policyNo.present) {
      map['policy_no'] = Variable<String>(policyNo.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<int>(expiryDate.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (driveFileId.present) {
      map['drive_file_id'] = Variable<String>(driveFileId.value);
    }
    if (fileChecksumSha256.present) {
      map['file_checksum_sha256'] = Variable<String>(fileChecksumSha256.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastModifiedTimestamp.present) {
      map['last_modified_timestamp'] =
          Variable<int>(lastModifiedTimestamp.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (visibleFields.present) {
      map['visible_fields'] = Variable<String>(visibleFields.value);
    }
    if (hiddenContext.present) {
      map['hidden_context'] = Variable<String>(hiddenContext.value);
    }
    if (requiresAiScan.present) {
      map['requires_ai_scan'] = Variable<bool>(requiresAiScan.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehicleDocumentsCompanion(')
          ..write('id: $id, ')
          ..write('documentType: $documentType, ')
          ..write('title: $title, ')
          ..write('vehicleRegNo: $vehicleRegNo, ')
          ..write('policyNo: $policyNo, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('fileChecksumSha256: $fileChecksumSha256, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModifiedTimestamp: $lastModifiedTimestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('category: $category, ')
          ..write('visibleFields: $visibleFields, ')
          ..write('hiddenContext: $hiddenContext, ')
          ..write('requiresAiScan: $requiresAiScan, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queueIdMeta =
      const VerificationMeta('queueId');
  @override
  late final GeneratedColumn<int> queueId = GeneratedColumn<int>(
      'queue_id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _documentIdMeta =
      const VerificationMeta('documentId');
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
      'document_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _driveFileIdMeta =
      const VerificationMeta('driveFileId');
  @override
  late final GeneratedColumn<String> driveFileId = GeneratedColumn<String>(
      'drive_file_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastAttemptMeta =
      const VerificationMeta('lastAttempt');
  @override
  late final GeneratedColumn<int> lastAttempt = GeneratedColumn<int>(
      'last_attempt', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nextRetryAtMeta =
      const VerificationMeta('nextRetryAt');
  @override
  late final GeneratedColumn<int> nextRetryAt = GeneratedColumn<int>(
      'next_retry_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        queueId,
        documentId,
        action,
        driveFileId,
        retryCount,
        lastAttempt,
        nextRetryAt,
        errorMessage,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(Insertable<SyncQueueData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('queue_id')) {
      context.handle(_queueIdMeta,
          queueId.isAcceptableOrUnknown(data['queue_id']!, _queueIdMeta));
    }
    if (data.containsKey('document_id')) {
      context.handle(
          _documentIdMeta,
          documentId.isAcceptableOrUnknown(
              data['document_id']!, _documentIdMeta));
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('drive_file_id')) {
      context.handle(
          _driveFileIdMeta,
          driveFileId.isAcceptableOrUnknown(
              data['drive_file_id']!, _driveFileIdMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('last_attempt')) {
      context.handle(
          _lastAttemptMeta,
          lastAttempt.isAcceptableOrUnknown(
              data['last_attempt']!, _lastAttemptMeta));
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
          _nextRetryAtMeta,
          nextRetryAt.isAcceptableOrUnknown(
              data['next_retry_at']!, _nextRetryAtMeta));
    } else if (isInserting) {
      context.missing(_nextRetryAtMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {queueId};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      queueId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}queue_id'])!,
      documentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}document_id'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      driveFileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}drive_file_id']),
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      lastAttempt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_attempt']),
      nextRetryAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}next_retry_at'])!,
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int queueId;
  final String documentId;
  final String action;
  final String? driveFileId;
  final int retryCount;
  final int? lastAttempt;
  final int nextRetryAt;
  final String? errorMessage;
  final int createdAt;
  const SyncQueueData(
      {required this.queueId,
      required this.documentId,
      required this.action,
      this.driveFileId,
      required this.retryCount,
      this.lastAttempt,
      required this.nextRetryAt,
      this.errorMessage,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['queue_id'] = Variable<int>(queueId);
    map['document_id'] = Variable<String>(documentId);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || driveFileId != null) {
      map['drive_file_id'] = Variable<String>(driveFileId);
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastAttempt != null) {
      map['last_attempt'] = Variable<int>(lastAttempt);
    }
    map['next_retry_at'] = Variable<int>(nextRetryAt);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      queueId: Value(queueId),
      documentId: Value(documentId),
      action: Value(action),
      driveFileId: driveFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(driveFileId),
      retryCount: Value(retryCount),
      lastAttempt: lastAttempt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttempt),
      nextRetryAt: Value(nextRetryAt),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
    );
  }

  factory SyncQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      queueId: serializer.fromJson<int>(json['queueId']),
      documentId: serializer.fromJson<String>(json['documentId']),
      action: serializer.fromJson<String>(json['action']),
      driveFileId: serializer.fromJson<String?>(json['driveFileId']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastAttempt: serializer.fromJson<int?>(json['lastAttempt']),
      nextRetryAt: serializer.fromJson<int>(json['nextRetryAt']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'queueId': serializer.toJson<int>(queueId),
      'documentId': serializer.toJson<String>(documentId),
      'action': serializer.toJson<String>(action),
      'driveFileId': serializer.toJson<String?>(driveFileId),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastAttempt': serializer.toJson<int?>(lastAttempt),
      'nextRetryAt': serializer.toJson<int>(nextRetryAt),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  SyncQueueData copyWith(
          {int? queueId,
          String? documentId,
          String? action,
          Value<String?> driveFileId = const Value.absent(),
          int? retryCount,
          Value<int?> lastAttempt = const Value.absent(),
          int? nextRetryAt,
          Value<String?> errorMessage = const Value.absent(),
          int? createdAt}) =>
      SyncQueueData(
        queueId: queueId ?? this.queueId,
        documentId: documentId ?? this.documentId,
        action: action ?? this.action,
        driveFileId: driveFileId.present ? driveFileId.value : this.driveFileId,
        retryCount: retryCount ?? this.retryCount,
        lastAttempt: lastAttempt.present ? lastAttempt.value : this.lastAttempt,
        nextRetryAt: nextRetryAt ?? this.nextRetryAt,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
        createdAt: createdAt ?? this.createdAt,
      );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      queueId: data.queueId.present ? data.queueId.value : this.queueId,
      documentId:
          data.documentId.present ? data.documentId.value : this.documentId,
      action: data.action.present ? data.action.value : this.action,
      driveFileId:
          data.driveFileId.present ? data.driveFileId.value : this.driveFileId,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      lastAttempt:
          data.lastAttempt.present ? data.lastAttempt.value : this.lastAttempt,
      nextRetryAt:
          data.nextRetryAt.present ? data.nextRetryAt.value : this.nextRetryAt,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('queueId: $queueId, ')
          ..write('documentId: $documentId, ')
          ..write('action: $action, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(queueId, documentId, action, driveFileId,
      retryCount, lastAttempt, nextRetryAt, errorMessage, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.queueId == this.queueId &&
          other.documentId == this.documentId &&
          other.action == this.action &&
          other.driveFileId == this.driveFileId &&
          other.retryCount == this.retryCount &&
          other.lastAttempt == this.lastAttempt &&
          other.nextRetryAt == this.nextRetryAt &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> queueId;
  final Value<String> documentId;
  final Value<String> action;
  final Value<String?> driveFileId;
  final Value<int> retryCount;
  final Value<int?> lastAttempt;
  final Value<int> nextRetryAt;
  final Value<String?> errorMessage;
  final Value<int> createdAt;
  const SyncQueueCompanion({
    this.queueId = const Value.absent(),
    this.documentId = const Value.absent(),
    this.action = const Value.absent(),
    this.driveFileId = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastAttempt = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.queueId = const Value.absent(),
    required String documentId,
    required String action,
    this.driveFileId = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastAttempt = const Value.absent(),
    required int nextRetryAt,
    this.errorMessage = const Value.absent(),
    required int createdAt,
  })  : documentId = Value(documentId),
        action = Value(action),
        nextRetryAt = Value(nextRetryAt),
        createdAt = Value(createdAt);
  static Insertable<SyncQueueData> custom({
    Expression<int>? queueId,
    Expression<String>? documentId,
    Expression<String>? action,
    Expression<String>? driveFileId,
    Expression<int>? retryCount,
    Expression<int>? lastAttempt,
    Expression<int>? nextRetryAt,
    Expression<String>? errorMessage,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (queueId != null) 'queue_id': queueId,
      if (documentId != null) 'document_id': documentId,
      if (action != null) 'action': action,
      if (driveFileId != null) 'drive_file_id': driveFileId,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastAttempt != null) 'last_attempt': lastAttempt,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncQueueCompanion copyWith(
      {Value<int>? queueId,
      Value<String>? documentId,
      Value<String>? action,
      Value<String?>? driveFileId,
      Value<int>? retryCount,
      Value<int?>? lastAttempt,
      Value<int>? nextRetryAt,
      Value<String?>? errorMessage,
      Value<int>? createdAt}) {
    return SyncQueueCompanion(
      queueId: queueId ?? this.queueId,
      documentId: documentId ?? this.documentId,
      action: action ?? this.action,
      driveFileId: driveFileId ?? this.driveFileId,
      retryCount: retryCount ?? this.retryCount,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (queueId.present) {
      map['queue_id'] = Variable<int>(queueId.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (driveFileId.present) {
      map['drive_file_id'] = Variable<String>(driveFileId.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastAttempt.present) {
      map['last_attempt'] = Variable<int>(lastAttempt.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<int>(nextRetryAt.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('queueId: $queueId, ')
          ..write('documentId: $documentId, ')
          ..write('action: $action, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VehicleDocumentsTable vehicleDocuments =
      $VehicleDocumentsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [vehicleDocuments, syncQueue];
}

typedef $$VehicleDocumentsTableCreateCompanionBuilder
    = VehicleDocumentsCompanion Function({
  required String id,
  required String documentType,
  required String title,
  required String vehicleRegNo,
  Value<String?> policyNo,
  Value<int?> expiryDate,
  required String localFilePath,
  Value<String?> driveFileId,
  required String fileChecksumSha256,
  required String syncStatus,
  required int lastModifiedTimestamp,
  required int createdAt,
  Value<String> category,
  Value<String> visibleFields,
  Value<String?> hiddenContext,
  Value<bool> requiresAiScan,
  Value<int> rowid,
});
typedef $$VehicleDocumentsTableUpdateCompanionBuilder
    = VehicleDocumentsCompanion Function({
  Value<String> id,
  Value<String> documentType,
  Value<String> title,
  Value<String> vehicleRegNo,
  Value<String?> policyNo,
  Value<int?> expiryDate,
  Value<String> localFilePath,
  Value<String?> driveFileId,
  Value<String> fileChecksumSha256,
  Value<String> syncStatus,
  Value<int> lastModifiedTimestamp,
  Value<int> createdAt,
  Value<String> category,
  Value<String> visibleFields,
  Value<String?> hiddenContext,
  Value<bool> requiresAiScan,
  Value<int> rowid,
});

class $$VehicleDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $VehicleDocumentsTable> {
  $$VehicleDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get documentType => $composableBuilder(
      column: $table.documentType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vehicleRegNo => $composableBuilder(
      column: $table.vehicleRegNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get policyNo => $composableBuilder(
      column: $table.policyNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get driveFileId => $composableBuilder(
      column: $table.driveFileId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileChecksumSha256 => $composableBuilder(
      column: $table.fileChecksumSha256,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastModifiedTimestamp => $composableBuilder(
      column: $table.lastModifiedTimestamp,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get visibleFields => $composableBuilder(
      column: $table.visibleFields, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hiddenContext => $composableBuilder(
      column: $table.hiddenContext, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get requiresAiScan => $composableBuilder(
      column: $table.requiresAiScan,
      builder: (column) => ColumnFilters(column));
}

class $$VehicleDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $VehicleDocumentsTable> {
  $$VehicleDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get documentType => $composableBuilder(
      column: $table.documentType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vehicleRegNo => $composableBuilder(
      column: $table.vehicleRegNo,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get policyNo => $composableBuilder(
      column: $table.policyNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get driveFileId => $composableBuilder(
      column: $table.driveFileId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileChecksumSha256 => $composableBuilder(
      column: $table.fileChecksumSha256,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastModifiedTimestamp => $composableBuilder(
      column: $table.lastModifiedTimestamp,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get visibleFields => $composableBuilder(
      column: $table.visibleFields,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hiddenContext => $composableBuilder(
      column: $table.hiddenContext,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get requiresAiScan => $composableBuilder(
      column: $table.requiresAiScan,
      builder: (column) => ColumnOrderings(column));
}

class $$VehicleDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehicleDocumentsTable> {
  $$VehicleDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get documentType => $composableBuilder(
      column: $table.documentType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get vehicleRegNo => $composableBuilder(
      column: $table.vehicleRegNo, builder: (column) => column);

  GeneratedColumn<String> get policyNo =>
      $composableBuilder(column: $table.policyNo, builder: (column) => column);

  GeneratedColumn<int> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => column);

  GeneratedColumn<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => column);

  GeneratedColumn<String> get driveFileId => $composableBuilder(
      column: $table.driveFileId, builder: (column) => column);

  GeneratedColumn<String> get fileChecksumSha256 => $composableBuilder(
      column: $table.fileChecksumSha256, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<int> get lastModifiedTimestamp => $composableBuilder(
      column: $table.lastModifiedTimestamp, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get visibleFields => $composableBuilder(
      column: $table.visibleFields, builder: (column) => column);

  GeneratedColumn<String> get hiddenContext => $composableBuilder(
      column: $table.hiddenContext, builder: (column) => column);

  GeneratedColumn<bool> get requiresAiScan => $composableBuilder(
      column: $table.requiresAiScan, builder: (column) => column);
}

class $$VehicleDocumentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VehicleDocumentsTable,
    VehicleDocumentData,
    $$VehicleDocumentsTableFilterComposer,
    $$VehicleDocumentsTableOrderingComposer,
    $$VehicleDocumentsTableAnnotationComposer,
    $$VehicleDocumentsTableCreateCompanionBuilder,
    $$VehicleDocumentsTableUpdateCompanionBuilder,
    (
      VehicleDocumentData,
      BaseReferences<_$AppDatabase, $VehicleDocumentsTable, VehicleDocumentData>
    ),
    VehicleDocumentData,
    PrefetchHooks Function()> {
  $$VehicleDocumentsTableTableManager(
      _$AppDatabase db, $VehicleDocumentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehicleDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehicleDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehicleDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> documentType = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> vehicleRegNo = const Value.absent(),
            Value<String?> policyNo = const Value.absent(),
            Value<int?> expiryDate = const Value.absent(),
            Value<String> localFilePath = const Value.absent(),
            Value<String?> driveFileId = const Value.absent(),
            Value<String> fileChecksumSha256 = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> lastModifiedTimestamp = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> visibleFields = const Value.absent(),
            Value<String?> hiddenContext = const Value.absent(),
            Value<bool> requiresAiScan = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VehicleDocumentsCompanion(
            id: id,
            documentType: documentType,
            title: title,
            vehicleRegNo: vehicleRegNo,
            policyNo: policyNo,
            expiryDate: expiryDate,
            localFilePath: localFilePath,
            driveFileId: driveFileId,
            fileChecksumSha256: fileChecksumSha256,
            syncStatus: syncStatus,
            lastModifiedTimestamp: lastModifiedTimestamp,
            createdAt: createdAt,
            category: category,
            visibleFields: visibleFields,
            hiddenContext: hiddenContext,
            requiresAiScan: requiresAiScan,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String documentType,
            required String title,
            required String vehicleRegNo,
            Value<String?> policyNo = const Value.absent(),
            Value<int?> expiryDate = const Value.absent(),
            required String localFilePath,
            Value<String?> driveFileId = const Value.absent(),
            required String fileChecksumSha256,
            required String syncStatus,
            required int lastModifiedTimestamp,
            required int createdAt,
            Value<String> category = const Value.absent(),
            Value<String> visibleFields = const Value.absent(),
            Value<String?> hiddenContext = const Value.absent(),
            Value<bool> requiresAiScan = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VehicleDocumentsCompanion.insert(
            id: id,
            documentType: documentType,
            title: title,
            vehicleRegNo: vehicleRegNo,
            policyNo: policyNo,
            expiryDate: expiryDate,
            localFilePath: localFilePath,
            driveFileId: driveFileId,
            fileChecksumSha256: fileChecksumSha256,
            syncStatus: syncStatus,
            lastModifiedTimestamp: lastModifiedTimestamp,
            createdAt: createdAt,
            category: category,
            visibleFields: visibleFields,
            hiddenContext: hiddenContext,
            requiresAiScan: requiresAiScan,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$VehicleDocumentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $VehicleDocumentsTable,
    VehicleDocumentData,
    $$VehicleDocumentsTableFilterComposer,
    $$VehicleDocumentsTableOrderingComposer,
    $$VehicleDocumentsTableAnnotationComposer,
    $$VehicleDocumentsTableCreateCompanionBuilder,
    $$VehicleDocumentsTableUpdateCompanionBuilder,
    (
      VehicleDocumentData,
      BaseReferences<_$AppDatabase, $VehicleDocumentsTable, VehicleDocumentData>
    ),
    VehicleDocumentData,
    PrefetchHooks Function()>;
typedef $$SyncQueueTableCreateCompanionBuilder = SyncQueueCompanion Function({
  Value<int> queueId,
  required String documentId,
  required String action,
  Value<String?> driveFileId,
  Value<int> retryCount,
  Value<int?> lastAttempt,
  required int nextRetryAt,
  Value<String?> errorMessage,
  required int createdAt,
});
typedef $$SyncQueueTableUpdateCompanionBuilder = SyncQueueCompanion Function({
  Value<int> queueId,
  Value<String> documentId,
  Value<String> action,
  Value<String?> driveFileId,
  Value<int> retryCount,
  Value<int?> lastAttempt,
  Value<int> nextRetryAt,
  Value<String?> errorMessage,
  Value<int> createdAt,
});

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get queueId => $composableBuilder(
      column: $table.queueId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get documentId => $composableBuilder(
      column: $table.documentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get driveFileId => $composableBuilder(
      column: $table.driveFileId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get queueId => $composableBuilder(
      column: $table.queueId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get documentId => $composableBuilder(
      column: $table.documentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get driveFileId => $composableBuilder(
      column: $table.driveFileId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get queueId =>
      $composableBuilder(column: $table.queueId, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
      column: $table.documentId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get driveFileId => $composableBuilder(
      column: $table.driveFileId, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<int> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => column);

  GeneratedColumn<int> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncQueueTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncQueueTable,
    SyncQueueData,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      SyncQueueData,
      BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>
    ),
    SyncQueueData,
    PrefetchHooks Function()> {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> queueId = const Value.absent(),
            Value<String> documentId = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String?> driveFileId = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<int?> lastAttempt = const Value.absent(),
            Value<int> nextRetryAt = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
          }) =>
              SyncQueueCompanion(
            queueId: queueId,
            documentId: documentId,
            action: action,
            driveFileId: driveFileId,
            retryCount: retryCount,
            lastAttempt: lastAttempt,
            nextRetryAt: nextRetryAt,
            errorMessage: errorMessage,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> queueId = const Value.absent(),
            required String documentId,
            required String action,
            Value<String?> driveFileId = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<int?> lastAttempt = const Value.absent(),
            required int nextRetryAt,
            Value<String?> errorMessage = const Value.absent(),
            required int createdAt,
          }) =>
              SyncQueueCompanion.insert(
            queueId: queueId,
            documentId: documentId,
            action: action,
            driveFileId: driveFileId,
            retryCount: retryCount,
            lastAttempt: lastAttempt,
            nextRetryAt: nextRetryAt,
            errorMessage: errorMessage,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncQueueTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncQueueTable,
    SyncQueueData,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      SyncQueueData,
      BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>
    ),
    SyncQueueData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VehicleDocumentsTableTableManager get vehicleDocuments =>
      $$VehicleDocumentsTableTableManager(_db, _db.vehicleDocuments);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
}
