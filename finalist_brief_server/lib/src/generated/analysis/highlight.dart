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
import 'package:serverpod/serverpod.dart' as _is;

/// A window in the demo video worth watching.
abstract class Highlight
    implements _is.SerializableModel, _is.ProtocolSerialization {
  Highlight._({
    required this.startSec,
    required this.endSec,
    required this.whatIsShown,
    required this.whyItMatters,
  });

  factory Highlight({
    required int startSec,
    required int endSec,
    required String whatIsShown,
    required String whyItMatters,
  }) = _HighlightImpl;

  factory Highlight.fromJson(Map<String, dynamic> jsonSerialization) {
    return Highlight(
      startSec: jsonSerialization['startSec'] as int,
      endSec: jsonSerialization['endSec'] as int,
      whatIsShown: jsonSerialization['whatIsShown'] as String,
      whyItMatters: jsonSerialization['whyItMatters'] as String,
    );
  }

  int startSec;

  int endSec;

  String whatIsShown;

  String whyItMatters;

  /// Returns a shallow copy of this [Highlight]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Highlight copyWith({
    int? startSec,
    int? endSec,
    String? whatIsShown,
    String? whyItMatters,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Highlight',
      'startSec': startSec,
      'endSec': endSec,
      'whatIsShown': whatIsShown,
      'whyItMatters': whyItMatters,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Highlight',
      'startSec': startSec,
      'endSec': endSec,
      'whatIsShown': whatIsShown,
      'whyItMatters': whyItMatters,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _HighlightImpl extends Highlight {
  _HighlightImpl({
    required int startSec,
    required int endSec,
    required String whatIsShown,
    required String whyItMatters,
  }) : super._(
         startSec: startSec,
         endSec: endSec,
         whatIsShown: whatIsShown,
         whyItMatters: whyItMatters,
       );

  /// Returns a shallow copy of this [Highlight]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Highlight copyWith({
    int? startSec,
    int? endSec,
    String? whatIsShown,
    String? whyItMatters,
  }) {
    return Highlight(
      startSec: startSec ?? this.startSec,
      endSec: endSec ?? this.endSec,
      whatIsShown: whatIsShown ?? this.whatIsShown,
      whyItMatters: whyItMatters ?? this.whyItMatters,
    );
  }
}
