import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../hackathon/hackathon.dart';
import '../visualization/graph_view.dart';
import 'hackathon_workspace.dart';
import 'hackathons_screen.dart';

/// Top level of the demo: a Hackathons list, then one workspace per hackathon.
/// Opened workspaces stay alive, so leaving and returning keeps each one's
/// selection, filters and Competition mode. Opening a hackathon always lands
/// on its Overview.
class HackathonShell extends StatefulWidget {
  const HackathonShell({
    super.key,
    this.sources = hackathonSources,
    this.initial,
    this.preloaded = const {},
  });
  final List<HackathonSource> sources;

  /// Where to open straight into, e.g. from a link. Without one, the
  /// Hackathons list shows first.
  final WorkspaceLocation? initial;

  /// Already-loaded hackathons by ID; tests use this to skip asset loading.
  final Map<String, Hackathon> preloaded;

  @override
  State<HackathonShell> createState() => _HackathonShellState();
}

class _HackathonShellState extends State<HackathonShell> {
  late int _active = widget.sources.indexWhere(
    (s) => s.id == widget.initial?.hackathonId,
  );
  late bool _atList = _active < 0;
  late final Set<String> _opened = {
    if (_active >= 0) widget.sources[_active].id,
  };
  late final Map<String, Future<Hackathon>> _loads = {
    for (final s in widget.sources)
      s.id: widget.preloaded.containsKey(s.id)
          ? Future.value(widget.preloaded[s.id])
          : loadHackathon(s),
  };

  final _workspaceKeys = <String, GlobalKey>{};

  /// Every card opens its hackathon's Overview, whether or not a workspace
  /// already exists; what the judge did inside is kept, not resumed.
  void _open(int index) {
    final id = widget.sources[index].id;
    final first = _opened.add(id);
    setState(() {
      _active = index;
      _atList = false;
    });
    if (!first) {
      (_workspaceKeys[id]?.currentState as OverviewWorkspace?)?.showOverview();
    }
    _report(WorkspaceLocation(id));
  }

  void _home() {
    setState(() => _atList = true);
    _report(null);
  }

  /// Keeps the address in step with the hierarchy on screen.
  void _report(WorkspaceLocation? location) {
    if (!kIsWeb) return;
    SystemNavigator.routeInformationUpdated(
      uri: Uri.parse(location?.path ?? '/hackathons'),
      replace: true,
    );
  }

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: _atList ? 0 : 1 + _active,
    sizing: StackFit.expand,
    children: [
      HackathonsScreen(sources: widget.sources, loads: _loads, onOpen: _open),
      for (final (i, source) in widget.sources.indexed)
        // A workspace builds the first time it is opened, then stays.
        if (_opened.contains(source.id))
          _Loaded(
            key: ValueKey('workspace-${source.id}'),
            future: _loads[source.id]!,
            builder: (hackathon) => HackathonWorkspace(
              key: _workspaceKeys.putIfAbsent(source.id, () => GlobalKey()),
              hackathon: hackathon,
              location: widget.initial?.hackathonId == source.id
                  ? widget.initial
                  : null,
              active: !_atList && i == _active,
              onHackathons: _home,
              onLocation: (location) {
                if (!_atList && i == _active) _report(location);
              },
            ),
          )
        else
          const SizedBox.shrink(),
    ],
  );
}

class _Loaded extends StatelessWidget {
  const _Loaded({super.key, required this.future, required this.builder});
  final Future<Hackathon> future;
  final Widget Function(Hackathon) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<Hackathon>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasData) return builder(snapshot.data!);
      return Scaffold(
        backgroundColor: paper,
        body: Center(
          child: snapshot.hasError
              ? Text('Could not load this hackathon: ${snapshot.error}')
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
