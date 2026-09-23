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
import 'dart:async' as _ida;
import 'package:finalist_brief_client/src/protocol/analysis/submission_analysis.dart'
    as _i4t0zdqu;
import 'package:finalist_brief_client/src/protocol/brief/brief.dart'
    as _ikvm6cks;
import 'package:finalist_brief_client/src/protocol/brief/brief_mode.dart'
    as _i9wm27te;
import 'package:finalist_brief_client/src/protocol/submissions/submission.dart'
    as _i1uicdbt;
import 'package:http/http.dart' as _i85jenna;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'protocol.dart' as _il2as5qe;

/// {@category Endpoint}
class EndpointAnalysis extends _isc.EndpointRef {
  EndpointAnalysis(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'analysis';

  /// The cached analysis of every submission (one per submission).
  _ida.Future<List<_i4t0zdqu.SubmissionAnalysis>> list() =>
      caller.callServerEndpoint<List<_i4t0zdqu.SubmissionAnalysis>>(
        'analysis',
        'list',
        {},
      );

  /// The cached analysis of one submission, or null if it has none.
  _ida.Future<_i4t0zdqu.SubmissionAnalysis?> forSubmission(int submissionId) =>
      caller.callServerEndpoint<_i4t0zdqu.SubmissionAnalysis?>(
        'analysis',
        'forSubmission',
        {'submissionId': submissionId},
      );
}

/// {@category Endpoint}
class EndpointBrief extends _isc.EndpointRef {
  EndpointBrief(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'brief';

  /// Starts a briefing run and returns it immediately. Poll [get] for progress.
  ///
  /// Only [BriefMode.replay] runs in Phase 1; it walks the cached demo data.
  _ida.Future<_ikvm6cks.Brief> generate(_i9wm27te.BriefMode mode) =>
      caller.callServerEndpoint<_ikvm6cks.Brief>(
        'brief',
        'generate',
        {'mode': mode},
      );

  /// Current state of a briefing run. Replay briefs advance on every call.
  _ida.Future<_ikvm6cks.Brief?> get(int id) =>
      caller.callServerEndpoint<_ikvm6cks.Brief?>(
        'brief',
        'get',
        {'id': id},
      );

  /// The most recently completed briefing, if any.
  _ida.Future<_ikvm6cks.Brief?> latestComplete() =>
      caller.callServerEndpoint<_ikvm6cks.Brief?>(
        'brief',
        'latestComplete',
        {},
      );
}

/// {@category Endpoint}
class EndpointSubmission extends _isc.EndpointRef {
  EndpointSubmission(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'submission';

  /// All submissions of the fixed Humor Genome dataset, in display order.
  _ida.Future<List<_i1uicdbt.Submission>> list() =>
      caller.callServerEndpoint<List<_i1uicdbt.Submission>>(
        'submission',
        'list',
        {},
      );
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _isc.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    analysis = EndpointAnalysis(this);
    brief = EndpointBrief(this);
    submission = EndpointSubmission(this);
  }

  late final EndpointAnalysis analysis;

  late final EndpointBrief brief;

  late final EndpointSubmission submission;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'analysis': analysis,
    'brief': brief,
    'submission': submission,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {};
}
