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
import 'package:finalist_brief_server/src/generated/brief/brief_mode.dart'
    as _i55u17to;
import 'package:serverpod/serverpod.dart' as _is;
import '../analysis/analysis_endpoint.dart' as _im84c7g0;
import '../brief/brief_endpoint.dart' as _i6oojbq7;
import '../submissions/submission_endpoint.dart' as _ih1flson;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'analysis': _im84c7g0.AnalysisEndpoint()
        ..initialize(
          server,
          'analysis',
          null,
        ),
      'brief': _i6oojbq7.BriefEndpoint()
        ..initialize(
          server,
          'brief',
          null,
        ),
      'submission': _ih1flson.SubmissionEndpoint()
        ..initialize(
          server,
          'submission',
          null,
        ),
    };
    connectors['analysis'] = _is.EndpointConnector(
      name: 'analysis',
      endpoint: endpoints['analysis']!,
      methodConnectors: {
        'list': _is.MethodConnector(
          name: 'list',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['analysis'] as _im84c7g0.AnalysisEndpoint)
                  .list(session),
        ),
        'forSubmission': _is.MethodConnector(
          name: 'forSubmission',
          params: {
            'submissionId': _is.ParameterDescription(
              name: 'submissionId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['analysis'] as _im84c7g0.AnalysisEndpoint)
                  .forSubmission(
                    session,
                    params['submissionId'],
                  ),
        ),
      },
    );
    connectors['brief'] = _is.EndpointConnector(
      name: 'brief',
      endpoint: endpoints['brief']!,
      methodConnectors: {
        'generate': _is.MethodConnector(
          name: 'generate',
          params: {
            'mode': _is.ParameterDescription(
              name: 'mode',
              type: _is.getType<_i55u17to.BriefMode>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['brief'] as _i6oojbq7.BriefEndpoint).generate(
                    session,
                    params['mode'],
                  ),
        ),
        'get': _is.MethodConnector(
          name: 'get',
          params: {
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['brief'] as _i6oojbq7.BriefEndpoint).get(
                session,
                params['id'],
              ),
        ),
        'latestComplete': _is.MethodConnector(
          name: 'latestComplete',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['brief'] as _i6oojbq7.BriefEndpoint)
                  .latestComplete(session),
        ),
      },
    );
    connectors['submission'] = _is.EndpointConnector(
      name: 'submission',
      endpoint: endpoints['submission']!,
      methodConnectors: {
        'list': _is.MethodConnector(
          name: 'list',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['submission'] as _ih1flson.SubmissionEndpoint)
                      .list(session),
        ),
      },
    );
  }
}
