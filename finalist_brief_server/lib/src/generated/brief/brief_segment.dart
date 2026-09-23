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
import '../analysis/evidence_item.dart' as _igb1pf7r;

/// One surfaced project inside a briefing, in playback order.
abstract class BriefSegment
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BriefSegment._({
    required this.position,
    required this.submissionId,
    required this.slug,
    required this.title,
    required this.whySurfaced,
    required this.evidence,
    required this.clipStartSec,
    required this.clipEndSec,
    required this.narration,
  });

  factory BriefSegment({
    required int position,
    required int submissionId,
    required String slug,
    required String title,
    required String whySurfaced,
    required List<_igb1pf7r.EvidenceItem> evidence,
    required int clipStartSec,
    required int clipEndSec,
    required String narration,
  }) = _BriefSegmentImpl;

  factory BriefSegment.fromJson(Map<String, dynamic> jsonSerialization) {
    return BriefSegment(
      position: jsonSerialization['position'] as int,
      submissionId: jsonSerialization['submissionId'] as int,
      slug: jsonSerialization['slug'] as String,
      title: jsonSerialization['title'] as String,
      whySurfaced: jsonSerialization['whySurfaced'] as String,
      evidence: _i5o63ljm.Protocol().deserialize<List<_igb1pf7r.EvidenceItem>>(
        jsonSerialization['evidence'],
      ),
      clipStartSec: jsonSerialization['clipStartSec'] as int,
      clipEndSec: jsonSerialization['clipEndSec'] as int,
      narration: jsonSerialization['narration'] as String,
    );
  }

  int position;

  int submissionId;

  String slug;

  String title;

  String whySurfaced;

  List<_igb1pf7r.EvidenceItem> evidence;

  int clipStartSec;

  int clipEndSec;

  String narration;

  /// Returns a shallow copy of this [BriefSegment]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BriefSegment copyWith({
    int? position,
    int? submissionId,
    String? slug,
    String? title,
    String? whySurfaced,
    List<_igb1pf7r.EvidenceItem>? evidence,
    int? clipStartSec,
    int? clipEndSec,
    String? narration,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BriefSegment',
      'position': position,
      'submissionId': submissionId,
      'slug': slug,
      'title': title,
      'whySurfaced': whySurfaced,
      'evidence': evidence.toJson(valueToJson: (v) => v.toJson()),
      'clipStartSec': clipStartSec,
      'clipEndSec': clipEndSec,
      'narration': narration,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BriefSegment',
      'position': position,
      'submissionId': submissionId,
      'slug': slug,
      'title': title,
      'whySurfaced': whySurfaced,
      'evidence': evidence.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'clipStartSec': clipStartSec,
      'clipEndSec': clipEndSec,
      'narration': narration,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _BriefSegmentImpl extends BriefSegment {
  _BriefSegmentImpl({
    required int position,
    required int submissionId,
    required String slug,
    required String title,
    required String whySurfaced,
    required List<_igb1pf7r.EvidenceItem> evidence,
    required int clipStartSec,
    required int clipEndSec,
    required String narration,
  }) : super._(
         position: position,
         submissionId: submissionId,
         slug: slug,
         title: title,
         whySurfaced: whySurfaced,
         evidence: evidence,
         clipStartSec: clipStartSec,
         clipEndSec: clipEndSec,
         narration: narration,
       );

  /// Returns a shallow copy of this [BriefSegment]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BriefSegment copyWith({
    int? position,
    int? submissionId,
    String? slug,
    String? title,
    String? whySurfaced,
    List<_igb1pf7r.EvidenceItem>? evidence,
    int? clipStartSec,
    int? clipEndSec,
    String? narration,
  }) {
    return BriefSegment(
      position: position ?? this.position,
      submissionId: submissionId ?? this.submissionId,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      whySurfaced: whySurfaced ?? this.whySurfaced,
      evidence: evidence ?? this.evidence.map((e0) => e0.copyWith()).toList(),
      clipStartSec: clipStartSec ?? this.clipStartSec,
      clipEndSec: clipEndSec ?? this.clipEndSec,
      narration: narration ?? this.narration,
    );
  }
}
