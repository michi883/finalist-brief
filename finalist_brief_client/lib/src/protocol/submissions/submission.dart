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

/// One hackathon submission from the fixed Humor Genome dataset.
abstract class Submission
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Submission._({
    this.id,
    required this.slug,
    required this.title,
    required this.creator,
    required this.summary,
    required this.gemmaUse,
    required this.kaggleUrl,
    this.repoUrl,
    this.demoUrl,
    required this.hasDemoVideo,
    required this.coverAsset,
    required this.sortOrder,
  });

  factory Submission({
    int? id,
    required String slug,
    required String title,
    required String creator,
    required String summary,
    required String gemmaUse,
    required String kaggleUrl,
    String? repoUrl,
    String? demoUrl,
    required bool hasDemoVideo,
    required String coverAsset,
    required int sortOrder,
  }) = _SubmissionImpl;

  factory Submission.fromJson(Map<String, dynamic> jsonSerialization) {
    return Submission(
      id: jsonSerialization['id'] as int?,
      slug: jsonSerialization['slug'] as String,
      title: jsonSerialization['title'] as String,
      creator: jsonSerialization['creator'] as String,
      summary: jsonSerialization['summary'] as String,
      gemmaUse: jsonSerialization['gemmaUse'] as String,
      kaggleUrl: jsonSerialization['kaggleUrl'] as String,
      repoUrl: jsonSerialization['repoUrl'] as String?,
      demoUrl: jsonSerialization['demoUrl'] as String?,
      hasDemoVideo: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['hasDemoVideo'],
      ),
      coverAsset: jsonSerialization['coverAsset'] as String,
      sortOrder: jsonSerialization['sortOrder'] as int,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// Stable key used for cache files, cover assets and fixture lookups.
  String slug;

  String title;

  String creator;

  /// One-line description from the writeup.
  String summary;

  /// How the writeup says Gemma is used.
  String gemmaUse;

  String kaggleUrl;

  String? repoUrl;

  /// YouTube video, Kaggle notebook or live site, whichever the writeup links.
  String? demoUrl;

  /// True when demoUrl is an actual video the briefing can cut from.
  bool hasDemoVideo;

  /// File name of the cover image bundled with the Flutter app.
  String coverAsset;

  int sortOrder;

  /// Returns a shallow copy of this [Submission]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Submission copyWith({
    int? id,
    String? slug,
    String? title,
    String? creator,
    String? summary,
    String? gemmaUse,
    String? kaggleUrl,
    String? repoUrl,
    String? demoUrl,
    bool? hasDemoVideo,
    String? coverAsset,
    int? sortOrder,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Submission',
      if (id != null) 'id': id,
      'slug': slug,
      'title': title,
      'creator': creator,
      'summary': summary,
      'gemmaUse': gemmaUse,
      'kaggleUrl': kaggleUrl,
      if (repoUrl != null) 'repoUrl': repoUrl,
      if (demoUrl != null) 'demoUrl': demoUrl,
      'hasDemoVideo': hasDemoVideo,
      'coverAsset': coverAsset,
      'sortOrder': sortOrder,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Submission',
      if (id != null) 'id': id,
      'slug': slug,
      'title': title,
      'creator': creator,
      'summary': summary,
      'gemmaUse': gemmaUse,
      'kaggleUrl': kaggleUrl,
      if (repoUrl != null) 'repoUrl': repoUrl,
      if (demoUrl != null) 'demoUrl': demoUrl,
      'hasDemoVideo': hasDemoVideo,
      'coverAsset': coverAsset,
      'sortOrder': sortOrder,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SubmissionImpl extends Submission {
  _SubmissionImpl({
    int? id,
    required String slug,
    required String title,
    required String creator,
    required String summary,
    required String gemmaUse,
    required String kaggleUrl,
    String? repoUrl,
    String? demoUrl,
    required bool hasDemoVideo,
    required String coverAsset,
    required int sortOrder,
  }) : super._(
         id: id,
         slug: slug,
         title: title,
         creator: creator,
         summary: summary,
         gemmaUse: gemmaUse,
         kaggleUrl: kaggleUrl,
         repoUrl: repoUrl,
         demoUrl: demoUrl,
         hasDemoVideo: hasDemoVideo,
         coverAsset: coverAsset,
         sortOrder: sortOrder,
       );

  /// Returns a shallow copy of this [Submission]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Submission copyWith({
    Object? id = _Undefined,
    String? slug,
    String? title,
    String? creator,
    String? summary,
    String? gemmaUse,
    String? kaggleUrl,
    Object? repoUrl = _Undefined,
    Object? demoUrl = _Undefined,
    bool? hasDemoVideo,
    String? coverAsset,
    int? sortOrder,
  }) {
    return Submission(
      id: id is int? ? id : this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      creator: creator ?? this.creator,
      summary: summary ?? this.summary,
      gemmaUse: gemmaUse ?? this.gemmaUse,
      kaggleUrl: kaggleUrl ?? this.kaggleUrl,
      repoUrl: repoUrl is String? ? repoUrl : this.repoUrl,
      demoUrl: demoUrl is String? ? demoUrl : this.demoUrl,
      hasDemoVideo: hasDemoVideo ?? this.hasDemoVideo,
      coverAsset: coverAsset ?? this.coverAsset,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
