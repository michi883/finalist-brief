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
import 'package:finalist_brief_client/src/protocol/protocol.dart' as _i4m2l4kj;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import '../brief/brief_mode.dart' as _iujhxvyn;
import '../brief/brief_segment.dart' as _ip1jtoez;
import '../brief/brief_status.dart' as _iywvqpzp;

/// A finalist briefing run and its result.
abstract class Brief
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
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
      stageLog: _i4m2l4kj.Protocol().deserialize<List<String>>(
        jsonSerialization['stageLog'],
      ),
      submissionCount: jsonSerialization['submissionCount'] as int,
      segments: jsonSerialization['segments'] == null
          ? null
          : _i4m2l4kj.Protocol().deserialize<List<_ip1jtoez.BriefSegment>>(
              jsonSerialization['segments'],
            ),
      videoUrl: jsonSerialization['videoUrl'] as String?,
      videoDurationSec: jsonSerialization['videoDurationSec'] as int?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
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

  /// Returns a shallow copy of this [Brief]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
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

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
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
  @_isc.useResult
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
