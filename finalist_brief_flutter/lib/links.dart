import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in a new tab (web) or the system browser.
Future<void> openUrl(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Parses an evidence `ref` of the form `t=<seconds>`; null for anything else.
int? timestampOf(String? ref) {
  if (ref == null || !ref.startsWith('t=')) return null;
  return int.tryParse(ref.substring(2));
}

/// `84` → `1:24`.
String formatTimestamp(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// A demo video link that starts at [seconds] (YouTube `t=` parameter).
String demoUrlAt(String demoUrl, int seconds) {
  final uri = Uri.parse(demoUrl);
  if (!uri.host.contains('youtube.com') && !uri.host.contains('youtu.be')) {
    return demoUrl;
  }
  return uri
      .replace(queryParameters: {...uri.queryParameters, 't': '${seconds}s'})
      .toString();
}
