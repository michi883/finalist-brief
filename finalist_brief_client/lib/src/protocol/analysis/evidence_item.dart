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
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import '../analysis/evidence_source.dart' as _ijez6x9l;

/// A concrete, checkable piece of evidence behind an assessment.
abstract class EvidenceItem
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  EvidenceItem._({
    required this.source,
    required this.detail,
    this.ref,
  });

  factory EvidenceItem({
    required _ijez6x9l.EvidenceSource source,
    required String detail,
    String? ref,
  }) = _EvidenceItemImpl;

  factory EvidenceItem.fromJson(Map<String, dynamic> jsonSerialization) {
    return EvidenceItem(
      source: _ijez6x9l.EvidenceSource.fromJson(
        (jsonSerialization['source'] as String),
      ),
      detail: jsonSerialization['detail'] as String,
      ref: jsonSerialization['ref'] as String?,
    );
  }

  _ijez6x9l.EvidenceSource source;

  String detail;

  /// A URL, a repo path, or "t=<seconds>" for a video timestamp.
  String? ref;

  /// Returns a shallow copy of this [EvidenceItem]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  EvidenceItem copyWith({
    _ijez6x9l.EvidenceSource? source,
    String? detail,
    String? ref,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EvidenceItem',
      'source': source.toJson(),
      'detail': detail,
      if (ref != null) 'ref': ref,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'EvidenceItem',
      'source': source.toJson(),
      'detail': detail,
      if (ref != null) 'ref': ref,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _EvidenceItemImpl extends EvidenceItem {
  _EvidenceItemImpl({
    required _ijez6x9l.EvidenceSource source,
    required String detail,
    String? ref,
  }) : super._(
         source: source,
         detail: detail,
         ref: ref,
       );

  /// Returns a shallow copy of this [EvidenceItem]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  EvidenceItem copyWith({
    _ijez6x9l.EvidenceSource? source,
    String? detail,
    Object? ref = _Undefined,
  }) {
    return EvidenceItem(
      source: source ?? this.source,
      detail: detail ?? this.detail,
      ref: ref is String? ? ref : this.ref,
    );
  }
}
