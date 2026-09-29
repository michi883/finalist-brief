import 'package:flutter/material.dart';

import 'client.dart';
import 'demo_mode.dart';
import 'screens/submissions_screen.dart';
import 'views/hackathon_shell.dart';
import 'views/hackathon_workspace.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The visual demo is fully local. The retained video flow is opt-in only.
  if (Uri.base.queryParameters['legacy'] == '1') await initializeClient();
  runApp(const FinalistBriefApp());
}

/// Restrained ink, paper and green for the shared visualization grammar.
ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF26776D),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    chipTheme: const ChipThemeData(
      padding: EdgeInsets.symmetric(horizontal: 6),
      labelPadding: EdgeInsets.symmetric(horizontal: 4),
    ),
  );
}

class FinalistBriefApp extends StatelessWidget {
  const FinalistBriefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finalist Brief',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.light,
      // Any address opens the one shell; the path picks where inside it.
      onGenerateInitialRoutes: (name) => [_route(name)],
      onGenerateRoute: (settings) => _route(settings.name),
    );
  }

  Route<void> _route(String? name) => MaterialPageRoute<void>(
    settings: RouteSettings(name: name),
    builder: (_) => Uri.base.queryParameters['legacy'] == '1'
        ? SubmissionsScreen(demoMode: isDemoMode)
        : HackathonShell(initial: _initial(name)),
  );

  /// `/hackathons/serverpod/competition/naggy`, or the development link
  /// `?hackathon=serverpod`; anything else shows the Hackathons list.
  WorkspaceLocation? _initial(String? name) {
    final linked = Uri.base.queryParameters['hackathon'];
    return WorkspaceLocation.parse(name) ??
        (linked == null ? null : WorkspaceLocation(linked));
  }
}
