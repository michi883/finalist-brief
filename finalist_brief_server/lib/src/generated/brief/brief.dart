/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:finalist_brief_server/src/generated/protocol.dart' as _i5o63ljm;
import 'package:serverpod/serverpod.dart' as _is;
import '../brief/brief_mode.dart' as _iujhxvyn;
import '../brief/brief_segment.dart' as _ip1jtoez;
import '../brief/brief_status.dart' as _iywvqpzp;

/// A finalist briefing run and its result.
abstract class Brief implements _is.TableRow<int?>, _is.ProtocolSerialization {
  Brief._({
    this.id,
    required this.status,
    required this.mode,
    required this.progressPercent,
    required this.progressMessage,
    required this.stageLog,
    required this.submissionCount,
    this.segments,
    this.videoUrl,
    this.videoDurationSec,
    required this.createdAt,
    this.completedAt,
  });

  factory Brief({
    int? id,
    required _iywvqpzp.BriefStatus status,
    required _iujhxvyn.BriefMode mode,
    required int progressPercent,
    required String progressMessage,
    required List<String> stageLog,
    required int submissionCount,
    List<_ip1jtoez.BriefSegment>? segments,
    String? videoUrl,
    int? videoDurationSec,
    required DateTime createdAt,
    DateTime? completedAt,
  }) = _BriefImpl;

  factory Brief.fromJson(Map<String, dynamic> jsonSerialization) {
    return Brief(
      id: jsonSerialization['id'] as int?,
      status: _iywvqpzp.BriefStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      mode: _iujhxvyn.BriefMode.fromJson((jsonSerialization['mode'] as String)),
      progressPercent: jsonSerialization['progressPercent'] as int,
      progressMessage: jsonSerialization['progressMessage'] as String,
      stageLog: _i5o63ljm.Protocol().deserialize<List<String>>(
        jsonSerialization['stageLog'],
      ),
      submissionCount: jsonSerialization['submissionCount'] as int,
      segments: jsonSerialization['segments'] == null
          ? null
          : _i5o63ljm.Protocol().deserialize<List<_ip1jtoez.BriefSegment>>(
              jsonSerialization['segments'],
            ),
      videoUrl: jsonSerialization['videoUrl'] as String?,
      videoDurationSec: jsonSerialization['videoDurationSec'] as int?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
    );
  }

  static final t = BriefTable();

  static const db = BriefRepository._();

  @override
  int? id;

  _iywvqpzp.BriefStatus status;

  _iujhxvyn.BriefMode mode;

  int progressPercent;

  String progressMessage;

  List<String> stageLog;

  int submissionCount;

  /// Exactly three when complete.
  List<_ip1jtoez.BriefSegment>? segments;

  String? videoUrl;

  int? videoDurationSec;

  DateTime createdAt;

  DateTime? completedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [Brief]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Brief copyWith({
    int? id,
    _iywvqpzp.BriefStatus? status,
    _iujhxvyn.BriefMode? mode,
    int? progressPercent,
    String? progressMessage,
    List<String>? stageLog,
    int? submissionCount,
    List<_ip1jtoez.BriefSegment>? segments,
    String? videoUrl,
    int? videoDurationSec,
    DateTime? createdAt,
    DateTime? completedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Brief',
      if (id != null) 'id': id,
      'status': status.toJson(),
      'mode': mode.toJson(),
      'progressPercent': progressPercent,
      'progressMessage': progressMessage,
      'stageLog': stageLog.toJson(),
      'submissionCount': submissionCount,
      if (segments != null)
        'segments': segments?.toJson(valueToJson: (v) => v.toJson()),
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (videoDurationSec != null) 'videoDurationSec': videoDurationSec,
      'createdAt': createdAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Brief',
      if (id != null) 'id': id,
      'status': status.toJson(),
      'mode': mode.toJson(),
      'progressPercent': progressPercent,
      'progressMessage': progressMessage,
      'stageLog': stageLog.toJson(),
      'submissionCount': submissionCount,
      if (segments != null)
        'segments': segments?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (videoDurationSec != null) 'videoDurationSec': videoDurationSec,
      'createdAt': createdAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
    };
  }

  static BriefInclude include() {
    return BriefInclude._();
  }

  static BriefIncludeList includeList({
    _is.WhereExpressionBuilder<BriefTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BriefTable>? orderBy,
    _is.OrderByListBuilder<BriefTable>? orderByList,
    BriefInclude? include,
  }) {
    return BriefIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Brief.t),
      orderByList: orderByList?.call(Brief.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BriefImpl extends Brief {
  _BriefImpl({
    int? id,
    required _iywvqpzp.BriefStatus status,
    required _iujhxvyn.BriefMode mode,
    required int progressPercent,
    required String progressMessage,
    required List<String> stageLog,
    required int submissionCount,
    List<_ip1jtoez.BriefSegment>? segments,
    String? videoUrl,
    int? videoDurationSec,
    required DateTime createdAt,
    DateTime? completedAt,
  }) : super._(
         id: id,
         status: status,
         mode: mode,
         progressPercent: progressPercent,
         progressMessage: progressMessage,
         stageLog: stageLog,
         submissionCount: submissionCount,
         segments: segments,
         videoUrl: videoUrl,
         videoDurationSec: videoDurationSec,
         createdAt: createdAt,
         completedAt: completedAt,
       );

  /// Returns a shallow copy of this [Brief]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Brief copyWith({
    Object? id = _Undefined,
    _iywvqpzp.BriefStatus? status,
    _iujhxvyn.BriefMode? mode,
    int? progressPercent,
    String? progressMessage,
    List<String>? stageLog,
    int? submissionCount,
    Object? segments = _Undefined,
    Object? videoUrl = _Undefined,
    Object? videoDurationSec = _Undefined,
    DateTime? createdAt,
    Object? completedAt = _Undefined,
  }) {
    return Brief(
      id: id is int? ? id : this.id,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      progressPercent: progressPercent ?? this.progressPercent,
      progressMessage: progressMessage ?? this.progressMessage,
      stageLog: stageLog ?? this.stageLog.map((e0) => e0).toList(),
      submissionCount: submissionCount ?? this.submissionCount,
      segments: segments is List<_ip1jtoez.BriefSegment>?
          ? segments
          : this.segments?.map((e0) => e0.copyWith()).toList(),
      videoUrl: videoUrl is String? ? videoUrl : this.videoUrl,
      videoDurationSec: videoDurationSec is int?
          ? videoDurationSec
          : this.videoDurationSec,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
    );
  }
}

class BriefUpdateTable extends _is.UpdateTable<BriefTable> {
  BriefUpdateTable(super.table);

  _is.ColumnValue<_iywvqpzp.BriefStatus, _iywvqpzp.BriefStatus> status(
    _iywvqpzp.BriefStatus value,
  ) => _is.ColumnValue(
    table.status,
    value,
  );

  _is.ColumnValue<_iujhxvyn.BriefMode, _iujhxvyn.BriefMode> mode(
    _iujhxvyn.BriefMode value,
  ) => _is.ColumnValue(
    table.mode,
    value,
  );

  _is.ColumnValue<int, int> progressPercent(int value) => _is.ColumnValue(
    table.progressPercent,
    value,
  );

  _is.ColumnValue<String, String> progressMessage(String value) =>
      _is.ColumnValue(
        table.progressMessage,
        value,
      );

  _is.ColumnValue<List<String>, List<String>> stageLog(List<String> value) =>
      _is.ColumnValue(
        table.stageLog,
        value,
      );

  _is.ColumnValue<int, int> submissionCount(int value) => _is.ColumnValue(
    table.submissionCount,
    value,
  );

  _is.ColumnValue<List<_ip1jtoez.BriefSegment>, List<_ip1jtoez.BriefSegment>>
  segments(List<_ip1jtoez.BriefSegment>? value) => _is.ColumnValue(
    table.segments,
    value,
  );

  _is.ColumnValue<String, String> videoUrl(String? value) => _is.ColumnValue(
    table.videoUrl,
    value,
  );

  _is.ColumnValue<int, int> videoDurationSec(int? value) => _is.ColumnValue(
    table.videoDurationSec,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _is.ColumnValue(
        table.completedAt,
        value,
      );
}

class BriefTable extends _is.Table<int?> {
  BriefTable({super.tableRelation}) : super(tableName: 'brief') {
    updateTable = BriefUpdateTable(this);
    status = _is.ColumnEnum(
      'status',
      this,
      _is.EnumSerialization.byName,
    );
    mode = _is.ColumnEnum(
      'mode',
      this,
      _is.EnumSerialization.byName,
    );
    progressPercent = _is.ColumnInt(
      'progressPercent',
      this,
    );
    progressMessage = _is.ColumnString(
      'progressMessage',
      this,
    );
    stageLog = _is.ColumnSerializable<List<String>>(
      'stageLog',
      this,
    );
    submissionCount = _is.ColumnInt(
      'submissionCount',
      this,
    );
    segments = _is.ColumnSerializable<List<_ip1jtoez.BriefSegment>>(
      'segments',
      this,
    );
    videoUrl = _is.ColumnString(
      'videoUrl',
      this,
    );
    videoDurationSec = _is.ColumnInt(
      'videoDurationSec',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    completedAt = _is.ColumnDateTime(
      'completedAt',
      this,
    );
  }

  late final BriefUpdateTable updateTable;

  late final _is.ColumnEnum<_iywvqpzp.BriefStatus> status;

  late final _is.ColumnEnum<_iujhxvyn.BriefMode> mode;

  late final _is.ColumnInt progressPercent;

  late final _is.ColumnString progressMessage;

  late final _is.ColumnSerializable<List<String>> stageLog;

  late final _is.ColumnInt submissionCount;

  /// Exactly three when complete.
  late final _is.ColumnSerializable<List<_ip1jtoez.BriefSegment>> segments;

  late final _is.ColumnString videoUrl;

  late final _is.ColumnInt videoDurationSec;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime completedAt;

  @override
  List<_is.Column> get columns => [
    id,
    status,
    mode,
    progressPercent,
    progressMessage,
    stageLog,
    submissionCount,
    segments,
    videoUrl,
    videoDurationSec,
    createdAt,
    completedAt,
  ];
}

class BriefInclude extends _is.IncludeObject {
  BriefInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => Brief.t;
}

class BriefIncludeList extends _is.IncludeList {
  BriefIncludeList._({
    _is.WhereExpressionBuilder<BriefTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Brief.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => Brief.t;
}

class BriefRepository {
  const BriefRepository._();

  /// Returns a list of [Brief]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<Brief>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BriefTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BriefTable>? orderBy,
    _is.OrderByListBuilder<BriefTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Brief>(
      where: where?.call(Brief.t),
      orderBy: orderBy?.call(Brief.t),
      orderByList: orderByList?.call(Brief.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Brief] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<Brief?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BriefTable>? where,
    int? offset,
    _is.OrderByBuilder<BriefTable>? orderBy,
    _is.OrderByListBuilder<BriefTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Brief>(
      where: where?.call(Brief.t),
      orderBy: orderBy?.call(Brief.t),
      orderByList: orderByList?.call(Brief.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Brief] by its [id] or null if no such row exists.
  Future<Brief?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Brief>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Brief]s in the list and returns the inserted rows.
  ///
  /// The returned [Brief]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Brief>> insert(
    _is.DatabaseSession session,
    List<Brief> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Brief>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Brief] and returns the inserted row.
  ///
  /// The returned [Brief] will have its `id` field set.
  Future<Brief> insertRow(
    _is.DatabaseSession session,
    Brief row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Brief>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Brief]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [Brief]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Brief>> upsert(
    _is.DatabaseSession session,
    List<Brief> rows, {
    required _is.ColumnSelections<BriefTable> conflictColumns,
    _is.ColumnSelections<BriefTable>? updateColumns,
    _is.WhereExpressionBuilder<BriefTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Brief>(
      rows,
      conflictColumns: conflictColumns(Brief.t),
      updateColumns: updateColumns?.call(Brief.t),
      updateWhere: updateWhere?.call(Brief.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Brief] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [Brief] will have its `id` field set.
  Future<Brief?> upsertRow(
    _is.DatabaseSession session,
    Brief row, {
    required _is.ColumnSelections<BriefTable> conflictColumns,
    _is.ColumnSelections<BriefTable>? updateColumns,
    _is.WhereExpressionBuilder<BriefTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Brief>(
      row,
      conflictColumns: conflictColumns(Brief.t),
      updateColumns: updateColumns?.call(Brief.t),
      updateWhere: updateWhere?.call(Brief.t),
      transaction: transaction,
    );
  }

  /// Updates all [Brief]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Brief>> update(
    _is.DatabaseSession session,
    List<Brief> rows, {
    _is.ColumnSelections<BriefTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Brief>(
      rows,
      columns: columns?.call(Brief.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Brief]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Brief> updateRow(
    _is.DatabaseSession session,
    Brief row, {
    _is.ColumnSelections<BriefTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Brief>(
      row,
      columns: columns?.call(Brief.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Brief] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Brief?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BriefUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Brief>(
      id,
      columnValues: columnValues(Brief.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Brief]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Brief>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BriefUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<BriefTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BriefTable>? orderBy,
    _is.OrderByListBuilder<BriefTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Brief>(
      columnValues: columnValues(Brief.t.updateTable),
      where: where(Brief.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Brief.t),
      orderByList: orderByList?.call(Brief.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Brief]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Brief>> delete(
    _is.DatabaseSession session,
    List<Brief> rows, {
    _is.OrderByBuilder<BriefTable>? orderBy,
    _is.OrderByListBuilder<BriefTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Brief>(
      rows,
      orderBy: orderBy?.call(Brief.t),
      orderByList: orderByList?.call(Brief.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Brief].
  Future<Brief> deleteRow(
    _is.DatabaseSession session,
    Brief row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Brief>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Brief>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BriefTable> where,
    _is.OrderByBuilder<BriefTable>? orderBy,
    _is.OrderByListBuilder<BriefTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Brief>(
      where: where(Brief.t),
      orderBy: orderBy?.call(Brief.t),
      orderByList: orderByList?.call(Brief.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BriefTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Brief>(
      where: where?.call(Brief.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Brief] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BriefTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Brief>(
      where: where(Brief.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
