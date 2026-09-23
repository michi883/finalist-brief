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
import '../analysis/area_assessment.dart' as _ilowces5;
import '../analysis/evidence_item.dart' as _igb1pf7r;
import '../analysis/highlight.dart' as _i3v8e61p;

/// Structured analysis of one submission. Phase 1 seeds these from
/// assets/demo/analyses.json (promptVersion "golden").
abstract class SubmissionAnalysis
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SubmissionAnalysis._({
    this.id,
    required this.submissionId,
    required this.promptVersion,
    required this.summary,
    required this.technical,
    required this.demonstration,
    required this.idea,
    required this.gemmaUsage,
    required this.worthCloserReview,
    required this.whyWorthAttention,
    this.whyNotSurfaced,
    required this.evidence,
    required this.highlights,
  });

  factory SubmissionAnalysis({
    int? id,
    required int submissionId,
    required String promptVersion,
    required String summary,
    required _ilowces5.AreaAssessment technical,
    required _ilowces5.AreaAssessment demonstration,
    required _ilowces5.AreaAssessment idea,
    required _ilowces5.AreaAssessment gemmaUsage,
    required bool worthCloserReview,
    required String whyWorthAttention,
    String? whyNotSurfaced,
    required List<_igb1pf7r.EvidenceItem> evidence,
    required List<_i3v8e61p.Highlight> highlights,
  }) = _SubmissionAnalysisImpl;

  factory SubmissionAnalysis.fromJson(Map<String, dynamic> jsonSerialization) {
    return SubmissionAnalysis(
      id: jsonSerialization['id'] as int?,
      submissionId: jsonSerialization['submissionId'] as int,
      promptVersion: jsonSerialization['promptVersion'] as String,
      summary: jsonSerialization['summary'] as String,
      technical: _i5o63ljm.Protocol().deserialize<_ilowces5.AreaAssessment>(
        jsonSerialization['technical'],
      ),
      demonstration: _i5o63ljm.Protocol().deserialize<_ilowces5.AreaAssessment>(
        jsonSerialization['demonstration'],
      ),
      idea: _i5o63ljm.Protocol().deserialize<_ilowces5.AreaAssessment>(
        jsonSerialization['idea'],
      ),
      gemmaUsage: _i5o63ljm.Protocol().deserialize<_ilowces5.AreaAssessment>(
        jsonSerialization['gemmaUsage'],
      ),
      worthCloserReview: _is.BoolJsonExtension.fromJson(
        jsonSerialization['worthCloserReview'],
      ),
      whyWorthAttention: jsonSerialization['whyWorthAttention'] as String,
      whyNotSurfaced: jsonSerialization['whyNotSurfaced'] as String?,
      evidence: _i5o63ljm.Protocol().deserialize<List<_igb1pf7r.EvidenceItem>>(
        jsonSerialization['evidence'],
      ),
      highlights: _i5o63ljm.Protocol().deserialize<List<_i3v8e61p.Highlight>>(
        jsonSerialization['highlights'],
      ),
    );
  }

  static final t = SubmissionAnalysisTable();

  static const db = SubmissionAnalysisRepository._();

  @override
  int? id;

  int submissionId;

  String promptVersion;

  String summary;

  _ilowces5.AreaAssessment technical;

  _ilowces5.AreaAssessment demonstration;

  _ilowces5.AreaAssessment idea;

  _ilowces5.AreaAssessment gemmaUsage;

  bool worthCloserReview;

  String whyWorthAttention;

  /// Short reason shown under "also analyzed" when not surfaced.
  String? whyNotSurfaced;

  List<_igb1pf7r.EvidenceItem> evidence;

  List<_i3v8e61p.Highlight> highlights;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SubmissionAnalysis]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SubmissionAnalysis copyWith({
    int? id,
    int? submissionId,
    String? promptVersion,
    String? summary,
    _ilowces5.AreaAssessment? technical,
    _ilowces5.AreaAssessment? demonstration,
    _ilowces5.AreaAssessment? idea,
    _ilowces5.AreaAssessment? gemmaUsage,
    bool? worthCloserReview,
    String? whyWorthAttention,
    String? whyNotSurfaced,
    List<_igb1pf7r.EvidenceItem>? evidence,
    List<_i3v8e61p.Highlight>? highlights,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SubmissionAnalysis',
      if (id != null) 'id': id,
      'submissionId': submissionId,
      'promptVersion': promptVersion,
      'summary': summary,
      'technical': technical.toJson(),
      'demonstration': demonstration.toJson(),
      'idea': idea.toJson(),
      'gemmaUsage': gemmaUsage.toJson(),
      'worthCloserReview': worthCloserReview,
      'whyWorthAttention': whyWorthAttention,
      if (whyNotSurfaced != null) 'whyNotSurfaced': whyNotSurfaced,
      'evidence': evidence.toJson(valueToJson: (v) => v.toJson()),
      'highlights': highlights.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SubmissionAnalysis',
      if (id != null) 'id': id,
      'submissionId': submissionId,
      'promptVersion': promptVersion,
      'summary': summary,
      'technical': technical.toJsonForProtocol(),
      'demonstration': demonstration.toJsonForProtocol(),
      'idea': idea.toJsonForProtocol(),
      'gemmaUsage': gemmaUsage.toJsonForProtocol(),
      'worthCloserReview': worthCloserReview,
      'whyWorthAttention': whyWorthAttention,
      if (whyNotSurfaced != null) 'whyNotSurfaced': whyNotSurfaced,
      'evidence': evidence.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'highlights': highlights.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
    };
  }

  static SubmissionAnalysisInclude include() {
    return SubmissionAnalysisInclude._();
  }

  static SubmissionAnalysisIncludeList includeList({
    _is.WhereExpressionBuilder<SubmissionAnalysisTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SubmissionAnalysisTable>? orderBy,
    _is.OrderByListBuilder<SubmissionAnalysisTable>? orderByList,
    SubmissionAnalysisInclude? include,
  }) {
    return SubmissionAnalysisIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SubmissionAnalysis.t),
      orderByList: orderByList?.call(SubmissionAnalysis.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SubmissionAnalysisImpl extends SubmissionAnalysis {
  _SubmissionAnalysisImpl({
    int? id,
    required int submissionId,
    required String promptVersion,
    required String summary,
    required _ilowces5.AreaAssessment technical,
    required _ilowces5.AreaAssessment demonstration,
    required _ilowces5.AreaAssessment idea,
    required _ilowces5.AreaAssessment gemmaUsage,
    required bool worthCloserReview,
    required String whyWorthAttention,
    String? whyNotSurfaced,
    required List<_igb1pf7r.EvidenceItem> evidence,
    required List<_i3v8e61p.Highlight> highlights,
  }) : super._(
         id: id,
         submissionId: submissionId,
         promptVersion: promptVersion,
         summary: summary,
         technical: technical,
         demonstration: demonstration,
         idea: idea,
         gemmaUsage: gemmaUsage,
         worthCloserReview: worthCloserReview,
         whyWorthAttention: whyWorthAttention,
         whyNotSurfaced: whyNotSurfaced,
         evidence: evidence,
         highlights: highlights,
       );

  /// Returns a shallow copy of this [SubmissionAnalysis]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SubmissionAnalysis copyWith({
    Object? id = _Undefined,
    int? submissionId,
    String? promptVersion,
    String? summary,
    _ilowces5.AreaAssessment? technical,
    _ilowces5.AreaAssessment? demonstration,
    _ilowces5.AreaAssessment? idea,
    _ilowces5.AreaAssessment? gemmaUsage,
    bool? worthCloserReview,
    String? whyWorthAttention,
    Object? whyNotSurfaced = _Undefined,
    List<_igb1pf7r.EvidenceItem>? evidence,
    List<_i3v8e61p.Highlight>? highlights,
  }) {
    return SubmissionAnalysis(
      id: id is int? ? id : this.id,
      submissionId: submissionId ?? this.submissionId,
      promptVersion: promptVersion ?? this.promptVersion,
      summary: summary ?? this.summary,
      technical: technical ?? this.technical.copyWith(),
      demonstration: demonstration ?? this.demonstration.copyWith(),
      idea: idea ?? this.idea.copyWith(),
      gemmaUsage: gemmaUsage ?? this.gemmaUsage.copyWith(),
      worthCloserReview: worthCloserReview ?? this.worthCloserReview,
      whyWorthAttention: whyWorthAttention ?? this.whyWorthAttention,
      whyNotSurfaced: whyNotSurfaced is String?
          ? whyNotSurfaced
          : this.whyNotSurfaced,
      evidence: evidence ?? this.evidence.map((e0) => e0.copyWith()).toList(),
      highlights:
          highlights ?? this.highlights.map((e0) => e0.copyWith()).toList(),
    );
  }
}

class SubmissionAnalysisUpdateTable
    extends _is.UpdateTable<SubmissionAnalysisTable> {
  SubmissionAnalysisUpdateTable(super.table);

  _is.ColumnValue<int, int> submissionId(int value) => _is.ColumnValue(
    table.submissionId,
    value,
  );

  _is.ColumnValue<String, String> promptVersion(String value) =>
      _is.ColumnValue(
        table.promptVersion,
        value,
      );

  _is.ColumnValue<String, String> summary(String value) => _is.ColumnValue(
    table.summary,
    value,
  );

  _is.ColumnValue<_ilowces5.AreaAssessment, _ilowces5.AreaAssessment> technical(
    _ilowces5.AreaAssessment value,
  ) => _is.ColumnValue(
    table.technical,
    value,
  );

  _is.ColumnValue<_ilowces5.AreaAssessment, _ilowces5.AreaAssessment>
  demonstration(_ilowces5.AreaAssessment value) => _is.ColumnValue(
    table.demonstration,
    value,
  );

  _is.ColumnValue<_ilowces5.AreaAssessment, _ilowces5.AreaAssessment> idea(
    _ilowces5.AreaAssessment value,
  ) => _is.ColumnValue(
    table.idea,
    value,
  );

  _is.ColumnValue<_ilowces5.AreaAssessment, _ilowces5.AreaAssessment>
  gemmaUsage(_ilowces5.AreaAssessment value) => _is.ColumnValue(
    table.gemmaUsage,
    value,
  );

  _is.ColumnValue<bool, bool> worthCloserReview(bool value) => _is.ColumnValue(
    table.worthCloserReview,
    value,
  );

  _is.ColumnValue<String, String> whyWorthAttention(String value) =>
      _is.ColumnValue(
        table.whyWorthAttention,
        value,
      );

  _is.ColumnValue<String, String> whyNotSurfaced(String? value) =>
      _is.ColumnValue(
        table.whyNotSurfaced,
        value,
      );

  _is.ColumnValue<List<_igb1pf7r.EvidenceItem>, List<_igb1pf7r.EvidenceItem>>
  evidence(List<_igb1pf7r.EvidenceItem> value) => _is.ColumnValue(
    table.evidence,
    value,
  );

  _is.ColumnValue<List<_i3v8e61p.Highlight>, List<_i3v8e61p.Highlight>>
  highlights(List<_i3v8e61p.Highlight> value) => _is.ColumnValue(
    table.highlights,
    value,
  );
}

class SubmissionAnalysisTable extends _is.Table<int?> {
  SubmissionAnalysisTable({super.tableRelation})
    : super(tableName: 'submission_analysis') {
    updateTable = SubmissionAnalysisUpdateTable(this);
    submissionId = _is.ColumnInt(
      'submissionId',
      this,
    );
    promptVersion = _is.ColumnString(
      'promptVersion',
      this,
    );
    summary = _is.ColumnString(
      'summary',
      this,
    );
    technical = _is.ColumnSerializable<_ilowces5.AreaAssessment>(
      'technical',
      this,
    );
    demonstration = _is.ColumnSerializable<_ilowces5.AreaAssessment>(
      'demonstration',
      this,
    );
    idea = _is.ColumnSerializable<_ilowces5.AreaAssessment>(
      'idea',
      this,
    );
    gemmaUsage = _is.ColumnSerializable<_ilowces5.AreaAssessment>(
      'gemmaUsage',
      this,
    );
    worthCloserReview = _is.ColumnBool(
      'worthCloserReview',
      this,
    );
    whyWorthAttention = _is.ColumnString(
      'whyWorthAttention',
      this,
    );
    whyNotSurfaced = _is.ColumnString(
      'whyNotSurfaced',
      this,
    );
    evidence = _is.ColumnSerializable<List<_igb1pf7r.EvidenceItem>>(
      'evidence',
      this,
    );
    highlights = _is.ColumnSerializable<List<_i3v8e61p.Highlight>>(
      'highlights',
      this,
    );
  }

  late final SubmissionAnalysisUpdateTable updateTable;

  late final _is.ColumnInt submissionId;

  late final _is.ColumnString promptVersion;

  late final _is.ColumnString summary;

  late final _is.ColumnSerializable<_ilowces5.AreaAssessment> technical;

  late final _is.ColumnSerializable<_ilowces5.AreaAssessment> demonstration;

  late final _is.ColumnSerializable<_ilowces5.AreaAssessment> idea;

  late final _is.ColumnSerializable<_ilowces5.AreaAssessment> gemmaUsage;

  late final _is.ColumnBool worthCloserReview;

  late final _is.ColumnString whyWorthAttention;

  /// Short reason shown under "also analyzed" when not surfaced.
  late final _is.ColumnString whyNotSurfaced;

  late final _is.ColumnSerializable<List<_igb1pf7r.EvidenceItem>> evidence;

  late final _is.ColumnSerializable<List<_i3v8e61p.Highlight>> highlights;

  @override
  List<_is.Column> get columns => [
    id,
    submissionId,
    promptVersion,
    summary,
    technical,
    demonstration,
    idea,
    gemmaUsage,
    worthCloserReview,
    whyWorthAttention,
    whyNotSurfaced,
    evidence,
    highlights,
  ];
}

class SubmissionAnalysisInclude extends _is.IncludeObject {
  SubmissionAnalysisInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SubmissionAnalysis.t;
}

class SubmissionAnalysisIncludeList extends _is.IncludeList {
  SubmissionAnalysisIncludeList._({
    _is.WhereExpressionBuilder<SubmissionAnalysisTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SubmissionAnalysis.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SubmissionAnalysis.t;
}

class SubmissionAnalysisRepository {
  const SubmissionAnalysisRepository._();

  /// Returns a list of [SubmissionAnalysis]s matching the given query parameters.
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
  Future<List<SubmissionAnalysis>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SubmissionAnalysisTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SubmissionAnalysisTable>? orderBy,
    _is.OrderByListBuilder<SubmissionAnalysisTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SubmissionAnalysis>(
      where: where?.call(SubmissionAnalysis.t),
      orderBy: orderBy?.call(SubmissionAnalysis.t),
      orderByList: orderByList?.call(SubmissionAnalysis.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [SubmissionAnalysis] matching the given query parameters.
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
  Future<SubmissionAnalysis?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SubmissionAnalysisTable>? where,
    int? offset,
    _is.OrderByBuilder<SubmissionAnalysisTable>? orderBy,
    _is.OrderByListBuilder<SubmissionAnalysisTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SubmissionAnalysis>(
      where: where?.call(SubmissionAnalysis.t),
      orderBy: orderBy?.call(SubmissionAnalysis.t),
      orderByList: orderByList?.call(SubmissionAnalysis.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SubmissionAnalysis] by its [id] or null if no such row exists.
  Future<SubmissionAnalysis?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SubmissionAnalysis>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SubmissionAnalysis]s in the list and returns the inserted rows.
  ///
  /// The returned [SubmissionAnalysis]s will have their `id` fields set.
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
  Future<List<SubmissionAnalysis>> insert(
    _is.DatabaseSession session,
    List<SubmissionAnalysis> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SubmissionAnalysis>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SubmissionAnalysis] and returns the inserted row.
  ///
  /// The returned [SubmissionAnalysis] will have its `id` field set.
  Future<SubmissionAnalysis> insertRow(
    _is.DatabaseSession session,
    SubmissionAnalysis row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SubmissionAnalysis>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SubmissionAnalysis]s in the list and returns the resulting rows.
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
  /// The returned [SubmissionAnalysis]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SubmissionAnalysis>> upsert(
    _is.DatabaseSession session,
    List<SubmissionAnalysis> rows, {
    required _is.ColumnSelections<SubmissionAnalysisTable> conflictColumns,
    _is.ColumnSelections<SubmissionAnalysisTable>? updateColumns,
    _is.WhereExpressionBuilder<SubmissionAnalysisTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SubmissionAnalysis>(
      rows,
      conflictColumns: conflictColumns(SubmissionAnalysis.t),
      updateColumns: updateColumns?.call(SubmissionAnalysis.t),
      updateWhere: updateWhere?.call(SubmissionAnalysis.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SubmissionAnalysis] and returns the resulting row.
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
  /// The returned [SubmissionAnalysis] will have its `id` field set.
  Future<SubmissionAnalysis?> upsertRow(
    _is.DatabaseSession session,
    SubmissionAnalysis row, {
    required _is.ColumnSelections<SubmissionAnalysisTable> conflictColumns,
    _is.ColumnSelections<SubmissionAnalysisTable>? updateColumns,
    _is.WhereExpressionBuilder<SubmissionAnalysisTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SubmissionAnalysis>(
      row,
      conflictColumns: conflictColumns(SubmissionAnalysis.t),
      updateColumns: updateColumns?.call(SubmissionAnalysis.t),
      updateWhere: updateWhere?.call(SubmissionAnalysis.t),
      transaction: transaction,
    );
  }

  /// Updates all [SubmissionAnalysis]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SubmissionAnalysis>> update(
    _is.DatabaseSession session,
    List<SubmissionAnalysis> rows, {
    _is.ColumnSelections<SubmissionAnalysisTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SubmissionAnalysis>(
      rows,
      columns: columns?.call(SubmissionAnalysis.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SubmissionAnalysis]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SubmissionAnalysis> updateRow(
    _is.DatabaseSession session,
    SubmissionAnalysis row, {
    _is.ColumnSelections<SubmissionAnalysisTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SubmissionAnalysis>(
      row,
      columns: columns?.call(SubmissionAnalysis.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SubmissionAnalysis] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SubmissionAnalysis?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SubmissionAnalysisUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SubmissionAnalysis>(
      id,
      columnValues: columnValues(SubmissionAnalysis.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SubmissionAnalysis]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SubmissionAnalysis>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SubmissionAnalysisUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<SubmissionAnalysisTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SubmissionAnalysisTable>? orderBy,
    _is.OrderByListBuilder<SubmissionAnalysisTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SubmissionAnalysis>(
      columnValues: columnValues(SubmissionAnalysis.t.updateTable),
      where: where(SubmissionAnalysis.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SubmissionAnalysis.t),
      orderByList: orderByList?.call(SubmissionAnalysis.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SubmissionAnalysis]s in the list and returns the deleted rows.
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
  Future<List<SubmissionAnalysis>> delete(
    _is.DatabaseSession session,
    List<SubmissionAnalysis> rows, {
    _is.OrderByBuilder<SubmissionAnalysisTable>? orderBy,
    _is.OrderByListBuilder<SubmissionAnalysisTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SubmissionAnalysis>(
      rows,
      orderBy: orderBy?.call(SubmissionAnalysis.t),
      orderByList: orderByList?.call(SubmissionAnalysis.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SubmissionAnalysis].
  Future<SubmissionAnalysis> deleteRow(
    _is.DatabaseSession session,
    SubmissionAnalysis row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SubmissionAnalysis>(
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
  Future<List<SubmissionAnalysis>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SubmissionAnalysisTable> where,
    _is.OrderByBuilder<SubmissionAnalysisTable>? orderBy,
    _is.OrderByListBuilder<SubmissionAnalysisTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SubmissionAnalysis>(
      where: where(SubmissionAnalysis.t),
      orderBy: orderBy?.call(SubmissionAnalysis.t),
      orderByList: orderByList?.call(SubmissionAnalysis.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SubmissionAnalysisTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SubmissionAnalysis>(
      where: where?.call(SubmissionAnalysis.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SubmissionAnalysis] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SubmissionAnalysisTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SubmissionAnalysis>(
      where: where(SubmissionAnalysis.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
