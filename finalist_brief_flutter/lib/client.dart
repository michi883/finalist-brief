import 'package:finalist_brief_shared/finalist_brief_shared.dart';

/// Base URL of the Finalist Brief API. Set it when building or running:
/// `flutter build web --dart-define=API_URL=https://finalist-brief-api-….run.app/`.
/// It defaults to a local `finalist_brief_api` on port 8080.
const _apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080/',
);

/// The API client used by the retained, opt-in `?legacy=1` screens. It is set
/// up by [initializeClient] before they open.
late final FinalistBriefApi api;

void initializeClient() {
  api = FinalistBriefApi(_apiUrl);
}
