// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ReadingsTable extends Readings with TableInfo<$ReadingsTable, Reading> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _systolicMeta = const VerificationMeta(
    'systolic',
  );
  @override
  late final GeneratedColumn<int> systolic = GeneratedColumn<int>(
    'systolic',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diastolicMeta = const VerificationMeta(
    'diastolic',
  );
  @override
  late final GeneratedColumn<int> diastolic = GeneratedColumn<int>(
    'diastolic',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pulseMeta = const VerificationMeta('pulse');
  @override
  late final GeneratedColumn<int> pulse = GeneratedColumn<int>(
    'pulse',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _temperatureFMeta = const VerificationMeta(
    'temperatureF',
  );
  @override
  late final GeneratedColumn<double> temperatureF = GeneratedColumn<double>(
    'temperature_f',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _measuredAtMeta = const VerificationMeta(
    'measuredAt',
  );
  @override
  late final GeneratedColumn<DateTime> measuredAt = GeneratedColumn<DateTime>(
    'measured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SyncStatus, String> syncStatus =
      GeneratedColumn<String>(
        'sync_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(SyncStatus.pending.name),
      ).withConverter<SyncStatus>($ReadingsTable.$convertersyncStatus);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    systolic,
    diastolic,
    pulse,
    temperatureF,
    measuredAt,
    syncStatus,
    attempts,
    lastError,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'readings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reading> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('systolic')) {
      context.handle(
        _systolicMeta,
        systolic.isAcceptableOrUnknown(data['systolic']!, _systolicMeta),
      );
    }
    if (data.containsKey('diastolic')) {
      context.handle(
        _diastolicMeta,
        diastolic.isAcceptableOrUnknown(data['diastolic']!, _diastolicMeta),
      );
    }
    if (data.containsKey('pulse')) {
      context.handle(
        _pulseMeta,
        pulse.isAcceptableOrUnknown(data['pulse']!, _pulseMeta),
      );
    }
    if (data.containsKey('temperature_f')) {
      context.handle(
        _temperatureFMeta,
        temperatureF.isAcceptableOrUnknown(
          data['temperature_f']!,
          _temperatureFMeta,
        ),
      );
    }
    if (data.containsKey('measured_at')) {
      context.handle(
        _measuredAtMeta,
        measuredAt.isAcceptableOrUnknown(data['measured_at']!, _measuredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_measuredAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reading map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reading(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      systolic: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}systolic'],
      ),
      diastolic: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}diastolic'],
      ),
      pulse: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pulse'],
      ),
      temperatureF: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature_f'],
      ),
      measuredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}measured_at'],
      )!,
      syncStatus: $ReadingsTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ReadingsTable createAlias(String alias) {
    return $ReadingsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncStatus, String, String> $convertersyncStatus =
      const EnumNameConverter<SyncStatus>(SyncStatus.values);
}

class Reading extends DataClass implements Insertable<Reading> {
  final String id;
  final String type;
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final double? temperatureF;
  final DateTime measuredAt;
  final SyncStatus syncStatus;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  const Reading({
    required this.id,
    required this.type,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.temperatureF,
    required this.measuredAt,
    required this.syncStatus,
    required this.attempts,
    this.lastError,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || systolic != null) {
      map['systolic'] = Variable<int>(systolic);
    }
    if (!nullToAbsent || diastolic != null) {
      map['diastolic'] = Variable<int>(diastolic);
    }
    if (!nullToAbsent || pulse != null) {
      map['pulse'] = Variable<int>(pulse);
    }
    if (!nullToAbsent || temperatureF != null) {
      map['temperature_f'] = Variable<double>(temperatureF);
    }
    map['measured_at'] = Variable<DateTime>(measuredAt);
    {
      map['sync_status'] = Variable<String>(
        $ReadingsTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ReadingsCompanion toCompanion(bool nullToAbsent) {
    return ReadingsCompanion(
      id: Value(id),
      type: Value(type),
      systolic: systolic == null && nullToAbsent
          ? const Value.absent()
          : Value(systolic),
      diastolic: diastolic == null && nullToAbsent
          ? const Value.absent()
          : Value(diastolic),
      pulse: pulse == null && nullToAbsent
          ? const Value.absent()
          : Value(pulse),
      temperatureF: temperatureF == null && nullToAbsent
          ? const Value.absent()
          : Value(temperatureF),
      measuredAt: Value(measuredAt),
      syncStatus: Value(syncStatus),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory Reading.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reading(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      systolic: serializer.fromJson<int?>(json['systolic']),
      diastolic: serializer.fromJson<int?>(json['diastolic']),
      pulse: serializer.fromJson<int?>(json['pulse']),
      temperatureF: serializer.fromJson<double?>(json['temperatureF']),
      measuredAt: serializer.fromJson<DateTime>(json['measuredAt']),
      syncStatus: $ReadingsTable.$convertersyncStatus.fromJson(
        serializer.fromJson<String>(json['syncStatus']),
      ),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'systolic': serializer.toJson<int?>(systolic),
      'diastolic': serializer.toJson<int?>(diastolic),
      'pulse': serializer.toJson<int?>(pulse),
      'temperatureF': serializer.toJson<double?>(temperatureF),
      'measuredAt': serializer.toJson<DateTime>(measuredAt),
      'syncStatus': serializer.toJson<String>(
        $ReadingsTable.$convertersyncStatus.toJson(syncStatus),
      ),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Reading copyWith({
    String? id,
    String? type,
    Value<int?> systolic = const Value.absent(),
    Value<int?> diastolic = const Value.absent(),
    Value<int?> pulse = const Value.absent(),
    Value<double?> temperatureF = const Value.absent(),
    DateTime? measuredAt,
    SyncStatus? syncStatus,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
  }) => Reading(
    id: id ?? this.id,
    type: type ?? this.type,
    systolic: systolic.present ? systolic.value : this.systolic,
    diastolic: diastolic.present ? diastolic.value : this.diastolic,
    pulse: pulse.present ? pulse.value : this.pulse,
    temperatureF: temperatureF.present ? temperatureF.value : this.temperatureF,
    measuredAt: measuredAt ?? this.measuredAt,
    syncStatus: syncStatus ?? this.syncStatus,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
  );
  Reading copyWithCompanion(ReadingsCompanion data) {
    return Reading(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      systolic: data.systolic.present ? data.systolic.value : this.systolic,
      diastolic: data.diastolic.present ? data.diastolic.value : this.diastolic,
      pulse: data.pulse.present ? data.pulse.value : this.pulse,
      temperatureF: data.temperatureF.present
          ? data.temperatureF.value
          : this.temperatureF,
      measuredAt: data.measuredAt.present
          ? data.measuredAt.value
          : this.measuredAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reading(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('systolic: $systolic, ')
          ..write('diastolic: $diastolic, ')
          ..write('pulse: $pulse, ')
          ..write('temperatureF: $temperatureF, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    systolic,
    diastolic,
    pulse,
    temperatureF,
    measuredAt,
    syncStatus,
    attempts,
    lastError,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reading &&
          other.id == this.id &&
          other.type == this.type &&
          other.systolic == this.systolic &&
          other.diastolic == this.diastolic &&
          other.pulse == this.pulse &&
          other.temperatureF == this.temperatureF &&
          other.measuredAt == this.measuredAt &&
          other.syncStatus == this.syncStatus &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class ReadingsCompanion extends UpdateCompanion<Reading> {
  final Value<String> id;
  final Value<String> type;
  final Value<int?> systolic;
  final Value<int?> diastolic;
  final Value<int?> pulse;
  final Value<double?> temperatureF;
  final Value<DateTime> measuredAt;
  final Value<SyncStatus> syncStatus;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ReadingsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.systolic = const Value.absent(),
    this.diastolic = const Value.absent(),
    this.pulse = const Value.absent(),
    this.temperatureF = const Value.absent(),
    this.measuredAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingsCompanion.insert({
    required String id,
    required String type,
    this.systolic = const Value.absent(),
    this.diastolic = const Value.absent(),
    this.pulse = const Value.absent(),
    this.temperatureF = const Value.absent(),
    required DateTime measuredAt,
    this.syncStatus = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       measuredAt = Value(measuredAt),
       createdAt = Value(createdAt);
  static Insertable<Reading> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<int>? systolic,
    Expression<int>? diastolic,
    Expression<int>? pulse,
    Expression<double>? temperatureF,
    Expression<DateTime>? measuredAt,
    Expression<String>? syncStatus,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (systolic != null) 'systolic': systolic,
      if (diastolic != null) 'diastolic': diastolic,
      if (pulse != null) 'pulse': pulse,
      if (temperatureF != null) 'temperature_f': temperatureF,
      if (measuredAt != null) 'measured_at': measuredAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<int?>? systolic,
    Value<int?>? diastolic,
    Value<int?>? pulse,
    Value<double?>? temperatureF,
    Value<DateTime>? measuredAt,
    Value<SyncStatus>? syncStatus,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ReadingsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      pulse: pulse ?? this.pulse,
      temperatureF: temperatureF ?? this.temperatureF,
      measuredAt: measuredAt ?? this.measuredAt,
      syncStatus: syncStatus ?? this.syncStatus,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (systolic.present) {
      map['systolic'] = Variable<int>(systolic.value);
    }
    if (diastolic.present) {
      map['diastolic'] = Variable<int>(diastolic.value);
    }
    if (pulse.present) {
      map['pulse'] = Variable<int>(pulse.value);
    }
    if (temperatureF.present) {
      map['temperature_f'] = Variable<double>(temperatureF.value);
    }
    if (measuredAt.present) {
      map['measured_at'] = Variable<DateTime>(measuredAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
        $ReadingsTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('systolic: $systolic, ')
          ..write('diastolic: $diastolic, ')
          ..write('pulse: $pulse, ')
          ..write('temperatureF: $temperatureF, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ReadingsTable readings = $ReadingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [readings];
}

typedef $$ReadingsTableCreateCompanionBuilder = ReadingsCompanion Function({
  required String id,
  required String type,
  Value<int?> systolic,
  Value<int?> diastolic,
  Value<int?> pulse,
  Value<double?> temperatureF,
  required DateTime measuredAt,
  Value<SyncStatus> syncStatus,
  Value<int> attempts,
  Value<String?> lastError,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ReadingsTableUpdateCompanionBuilder = ReadingsCompanion Function({
  Value<String> id,
  Value<String> type,
  Value<int?> systolic,
  Value<int?> diastolic,
  Value<int?> pulse,
  Value<double?> temperatureF,
  Value<DateTime> measuredAt,
  Value<SyncStatus> syncStatus,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ReadingsTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingsTable> {
  $$ReadingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get systolic => $composableBuilder(
    column: $table.systolic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diastolic => $composableBuilder(
    column: $table.diastolic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pulse => $composableBuilder(
    column: $table.pulse,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperatureF => $composableBuilder(
    column: $table.temperatureF,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncStatus, SyncStatus, String>
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingsTable> {
  $$ReadingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get systolic => $composableBuilder(
    column: $table.systolic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diastolic => $composableBuilder(
    column: $table.diastolic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pulse => $composableBuilder(
    column: $table.pulse,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperatureF => $composableBuilder(
    column: $table.temperatureF,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingsTable> {
  $$ReadingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get systolic =>
      $composableBuilder(column: $table.systolic, builder: (column) => column);

  GeneratedColumn<int> get diastolic =>
      $composableBuilder(column: $table.diastolic, builder: (column) => column);

  GeneratedColumn<int> get pulse =>
      $composableBuilder(column: $table.pulse, builder: (column) => column);

  GeneratedColumn<double> get temperatureF => $composableBuilder(
    column: $table.temperatureF,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SyncStatus, String> get syncStatus =>
      $composableBuilder(
        column: $table.syncStatus,
        builder: (column) => column,
      );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ReadingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingsTable,
          Reading,
          $$ReadingsTableFilterComposer,
          $$ReadingsTableOrderingComposer,
          $$ReadingsTableAnnotationComposer,
          $$ReadingsTableCreateCompanionBuilder,
          $$ReadingsTableUpdateCompanionBuilder,
          (Reading, BaseReferences<_$AppDatabase, $ReadingsTable, Reading>),
          Reading,
          PrefetchHooks Function()
        > {
  $$ReadingsTableTableManager(_$AppDatabase db, $ReadingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> systolic = const Value.absent(),
                Value<int?> diastolic = const Value.absent(),
                Value<int?> pulse = const Value.absent(),
                Value<double?> temperatureF = const Value.absent(),
                Value<DateTime> measuredAt = const Value.absent(),
                Value<SyncStatus> syncStatus = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingsCompanion(
                id: id,
                type: type,
                systolic: systolic,
                diastolic: diastolic,
                pulse: pulse,
                temperatureF: temperatureF,
                measuredAt: measuredAt,
                syncStatus: syncStatus,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                Value<int?> systolic = const Value.absent(),
                Value<int?> diastolic = const Value.absent(),
                Value<int?> pulse = const Value.absent(),
                Value<double?> temperatureF = const Value.absent(),
                required DateTime measuredAt,
                Value<SyncStatus> syncStatus = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ReadingsCompanion.insert(
                id: id,
                type: type,
                systolic: systolic,
                diastolic: diastolic,
                pulse: pulse,
                temperatureF: temperatureF,
                measuredAt: measuredAt,
                syncStatus: syncStatus,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingsTable, Reading>(table),
                  BaseReferences<_$AppDatabase, $ReadingsTable, Reading>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingsTable,
      Reading,
      $$ReadingsTableFilterComposer,
      $$ReadingsTableOrderingComposer,
      $$ReadingsTableAnnotationComposer,
      $$ReadingsTableCreateCompanionBuilder,
      $$ReadingsTableUpdateCompanionBuilder,
      (Reading, BaseReferences<_$AppDatabase, $ReadingsTable, Reading>),
      Reading,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ReadingsTableTableManager get readings =>
      $$ReadingsTableTableManager(_db, _db.readings);
}
