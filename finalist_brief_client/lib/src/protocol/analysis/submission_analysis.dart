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
import '../analysis/area_assessment.dart' as _ilowces5;
import '../analysis/evidence_item.dart' as _igb1pf7r;
import '../analysis/highlight.dart' as _i3v8e61p;

/// Structured analysis of one submission. Phase 1 seeds these from
/// assets/demo/analyses.json (promptVersion "golden").
abstract class SubmissionAnalysis
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
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
      technical: _i4m2l4kj.Protocol().deserialize<_ilowces5.AreaAssessment>(
        jsonSerialization['technical'],
      ),
      demonstration: _i4m2l4kj.Protocol().deserialize<_ilowces5.AreaAssessment>(
        jsonSerialization['demonstration'],
      ),
      idea: _i4m2l4kj.Protocol().deserialize<_ilowces5.AreaAssessment>(
        jsonSerialization['idea'],
      ),
      gemmaUsage: _i4m2l4kj.Protocol().deserialize<_ilowces5.AreaAssessment>(
        jsonSerialization['gemmaUsage'],
      ),
      worthCloserReview: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['worthCloserReview'],
      ),
      whyWorthAttention: jsonSerialization['whyWorthAttention'] as String,
      whyNotSurfaced: jsonSerialization['whyNotSurfaced'] as String?,
      evidence: _i4m2l4kj.Protocol().deserialize<List<_igb1pf7r.EvidenceItem>>(
        jsonSerialization['evidence'],
      ),
      highlights: _i4m2l4kj.Protocol().deserialize<List<_i3v8e61p.Highlight>>(
        jsonSerialization['highlights'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
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

  /// Returns a shallow copy of this [SubmissionAnalysis]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
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

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
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
  @_isc.useResult
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
