/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:finalist_brief_server/src/generated/analysis/submission_analysis.dart'
    as _idsevss0;
import 'package:finalist_brief_server/src/generated/submissions/submission.dart'
    as _iuin5zvq;
import 'package:serverpod/protocol.dart' as _isp;
import 'package:serverpod/serverpod.dart' as _is;
import 'analysis/area_assessment.dart' as _imdfyces;
import 'analysis/evidence_item.dart' as _ixom05iv;
import 'analysis/evidence_source.dart' as _ijvenog1;
import 'analysis/highlight.dart' as _ildh0ho9;
import 'analysis/submission_analysis.dart' as _idqp06n4;
import 'brief/brief.dart' as _i5ixxhe1;
import 'brief/brief_mode.dart' as _ibijdjzc;
import 'brief/brief_segment.dart' as _ibi1yann;
import 'brief/brief_status.dart' as _iceyys24;
import 'brief/brief_unavailable_exception.dart' as _i66lbz0i;
import 'submissions/submission.dart' as _ioknaqur;
export 'analysis/area_assessment.dart';
export 'analysis/evidence_item.dart';
export 'analysis/evidence_source.dart';
export 'analysis/highlight.dart';
export 'analysis/submission_analysis.dart';
export 'brief/brief.dart';
export 'brief/brief_mode.dart';
export 'brief/brief_segment.dart';
export 'brief/brief_status.dart';
export 'brief/brief_unavailable_exception.dart';
export 'submissions/submission.dart';

class Protocol extends _is.DatabaseSerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static List<_isp.TableDefinition> get targetTableDefinitions => [
    _isp.TableDefinition(
      name: 'brief',
      dartName: 'Brief',
      schema: 'public',
      module: 'finalist_brief',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'status',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:BriefStatus',
        ),
        _isp.ColumnDefinition(
          name: 'mode',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:BriefMode',
        ),
        _isp.ColumnDefinition(
          name: 'progressPercent',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'progressMessage',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'stageLog',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'List<String>',
        ),
        _isp.ColumnDefinition(
          name: 'submissionCount',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'segments',
          columnType: _isp.ColumnType.json,
          isNullable: true,
          dartType: 'List<protocol:BriefSegment>?',
        ),
        _isp.ColumnDefinition(
          name: 'videoUrl',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'videoDurationSec',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'completedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'submission',
      dartName: 'Submission',
      schema: 'public',
      module: 'finalist_brief',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'slug',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'title',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'creator',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'summary',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'gemmaUse',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'kaggleUrl',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'repoUrl',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'demoUrl',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'hasDemoVideo',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _isp.ColumnDefinition(
          name: 'coverAsset',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'sortOrder',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'submission__slug__unique_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'slug',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'submission_analysis',
      dartName: 'SubmissionAnalysis',
      schema: 'public',
      module: 'finalist_brief',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'submissionId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'promptVersion',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'summary',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'technical',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'protocol:AreaAssessment',
        ),
        _isp.ColumnDefinition(
          name: 'demonstration',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'protocol:AreaAssessment',
        ),
        _isp.ColumnDefinition(
          name: 'idea',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'protocol:AreaAssessment',
        ),
        _isp.ColumnDefinition(
          name: 'gemmaUsage',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'protocol:AreaAssessment',
        ),
        _isp.ColumnDefinition(
          name: 'worthCloserReview',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _isp.ColumnDefinition(
          name: 'whyWorthAttention',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'whyNotSurfaced',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'evidence',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'List<protocol:EvidenceItem>',
        ),
        _isp.ColumnDefinition(
          name: 'highlights',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'List<protocol:Highlight>',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'submission_analysis_fk_0',
          columns: ['submissionId'],
          referenceTable: 'submission',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'submission_analysis_version_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'submissionId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'promptVersion',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    ..._isp.Protocol.targetTableDefinitions,
  ];

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _is.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _imdfyces.AreaAssessment) {
      return _imdfyces.AreaAssessment.fromJson(data) as T;
    }
    if (t == _ixom05iv.EvidenceItem) {
      return _ixom05iv.EvidenceItem.fromJson(data) as T;
    }
    if (t == _ijvenog1.EvidenceSource) {
      return _ijvenog1.EvidenceSource.fromJson(data) as T;
    }
    if (t == _ildh0ho9.Highlight) {
      return _ildh0ho9.Highlight.fromJson(data) as T;
    }
    if (t == _idqp06n4.SubmissionAnalysis) {
      return _idqp06n4.SubmissionAnalysis.fromJson(data) as T;
    }
    if (t == _i5ixxhe1.Brief) {
      return _i5ixxhe1.Brief.fromJson(data) as T;
    }
    if (t == _ibijdjzc.BriefMode) {
      return _ibijdjzc.BriefMode.fromJson(data) as T;
    }
    if (t == _ibi1yann.BriefSegment) {
      return _ibi1yann.BriefSegment.fromJson(data) as T;
    }
    if (t == _iceyys24.BriefStatus) {
      return _iceyys24.BriefStatus.fromJson(data) as T;
    }
    if (t == _i66lbz0i.BriefUnavailableException) {
      return _i66lbz0i.BriefUnavailableException.fromJson(data) as T;
    }
    if (t == _ioknaqur.Submission) {
      return _ioknaqur.Submission.fromJson(data) as T;
    }
    if (t == _is.getType<_imdfyces.AreaAssessment?>()) {
      return (data != null ? _imdfyces.AreaAssessment.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ixom05iv.EvidenceItem?>()) {
      return (data != null ? _ixom05iv.EvidenceItem.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ijvenog1.EvidenceSource?>()) {
      return (data != null ? _ijvenog1.EvidenceSource.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ildh0ho9.Highlight?>()) {
      return (data != null ? _ildh0ho9.Highlight.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_idqp06n4.SubmissionAnalysis?>()) {
      return (data != null ? _idqp06n4.SubmissionAnalysis.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i5ixxhe1.Brief?>()) {
      return (data != null ? _i5ixxhe1.Brief.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ibijdjzc.BriefMode?>()) {
      return (data != null ? _ibijdjzc.BriefMode.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ibi1yann.BriefSegment?>()) {
      return (data != null ? _ibi1yann.BriefSegment.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iceyys24.BriefStatus?>()) {
      return (data != null ? _iceyys24.BriefStatus.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i66lbz0i.BriefUnavailableException?>()) {
      return (data != null
              ? _i66lbz0i.BriefUnavailableException.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ioknaqur.Submission?>()) {
      return (data != null ? _ioknaqur.Submission.fromJson(data) : null) as T;
    }
    if (t == List<_ixom05iv.EvidenceItem>) {
      return (data as List)
              .map((e) => deserialize<_ixom05iv.EvidenceItem>(e))
              .toList()
          as T;
    }
    if (t == List<_ildh0ho9.Highlight>) {
      return (data as List)
              .map((e) => deserialize<_ildh0ho9.Highlight>(e))
              .toList()
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_ibi1yann.BriefSegment>) {
      return (data as List)
              .map((e) => deserialize<_ibi1yann.BriefSegment>(e))
              .toList()
          as T;
    }
    if (t == _is.getType<List<_ibi1yann.BriefSegment>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_ibi1yann.BriefSegment>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_idsevss0.SubmissionAnalysis>) {
      return (data as List)
              .map((e) => deserialize<_idsevss0.SubmissionAnalysis>(e))
              .toList()
          as T;
    }
    if (t == List<_iuin5zvq.Submission>) {
      return (data as List)
              .map((e) => deserialize<_iuin5zvq.Submission>(e))
              .toList()
          as T;
    }
    try {
      return _isp.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _imdfyces.AreaAssessment => 'AreaAssessment',
      _ixom05iv.EvidenceItem => 'EvidenceItem',
      _ijvenog1.EvidenceSource => 'EvidenceSource',
      _ildh0ho9.Highlight => 'Highlight',
      _idqp06n4.SubmissionAnalysis => 'SubmissionAnalysis',
      _i5ixxhe1.Brief => 'Brief',
      _ibijdjzc.BriefMode => 'BriefMode',
      _ibi1yann.BriefSegment => 'BriefSegment',
      _iceyys24.BriefStatus => 'BriefStatus',
      _i66lbz0i.BriefUnavailableException => 'BriefUnavailableException',
      _ioknaqur.Submission => 'Submission',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'finalist_brief.',
        '',
      );
    }

    switch (data) {
      case _imdfyces.AreaAssessment():
        return 'AreaAssessment';
      case _ixom05iv.EvidenceItem():
        return 'EvidenceItem';
      case _ijvenog1.EvidenceSource():
        return 'EvidenceSource';
      case _ildh0ho9.Highlight():
        return 'Highlight';
      case _idqp06n4.SubmissionAnalysis():
        return 'SubmissionAnalysis';
      case _i5ixxhe1.Brief():
        return 'Brief';
      case _ibijdjzc.BriefMode():
        return 'BriefMode';
      case _ibi1yann.BriefSegment():
        return 'BriefSegment';
      case _iceyys24.BriefStatus():
        return 'BriefStatus';
      case _i66lbz0i.BriefUnavailableException():
        return 'BriefUnavailableException';
      case _ioknaqur.Submission():
        return 'Submission';
    }
    className = _isp.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.') ? className : 'serverpod.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'AreaAssessment') {
      return deserialize<_imdfyces.AreaAssessment>(data['data']);
    }
    if (dataClassName == 'EvidenceItem') {
      return deserialize<_ixom05iv.EvidenceItem>(data['data']);
    }
    if (dataClassName == 'EvidenceSource') {
      return deserialize<_ijvenog1.EvidenceSource>(data['data']);
    }
    if (dataClassName == 'Highlight') {
      return deserialize<_ildh0ho9.Highlight>(data['data']);
    }
    if (dataClassName == 'SubmissionAnalysis') {
      return deserialize<_idqp06n4.SubmissionAnalysis>(data['data']);
    }
    if (dataClassName == 'Brief') {
      return deserialize<_i5ixxhe1.Brief>(data['data']);
    }
    if (dataClassName == 'BriefMode') {
      return deserialize<_ibijdjzc.BriefMode>(data['data']);
    }
    if (dataClassName == 'BriefSegment') {
      return deserialize<_ibi1yann.BriefSegment>(data['data']);
    }
    if (dataClassName == 'BriefStatus') {
      return deserialize<_iceyys24.BriefStatus>(data['data']);
    }
    if (dataClassName == 'BriefUnavailableException') {
      return deserialize<_i66lbz0i.BriefUnavailableException>(data['data']);
    }
    if (dataClassName == 'Submission') {
      return deserialize<_ioknaqur.Submission>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _isp.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _is.Table? getTableForType(Type t) {
    {
      var table = _isp.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _idqp06n4.SubmissionAnalysis:
        return _idqp06n4.SubmissionAnalysis.t;
      case _i5ixxhe1.Brief:
        return _i5ixxhe1.Brief.t;
      case _ioknaqur.Submission:
        return _ioknaqur.Submission.t;
    }
    return null;
  }

  @override
  List<_isp.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'finalist_brief';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _isp.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
