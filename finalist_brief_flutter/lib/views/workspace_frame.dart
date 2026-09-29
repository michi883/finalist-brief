import 'package:flutter/material.dart';

import '../visualization/graph_view.dart';
import 'exploration_screen.dart' show BrandMark, brandBreakpoint;

/// The primary workspaces of every hackathon, in order.
enum WorkspaceTab {
  overview('Overview'),
  submissions('Submissions'),
  competition('Competition');

  const WorkspaceTab(this.label);
  final String label;
}

/// Horizontal room the page leaves on each side.
double workspaceGutter(double width) => width > 1100 ? 48 : 24;

/// The persistent header of a hackathon workspace, identical for every
/// hackathon: where you are (breadcrumb), which hackathon (title) and which
/// primary workspace (tabs). Everything below it is that workspace's content.
///
/// Only a project is a level below a workspace; filters and modes never
/// appear in the breadcrumb.
class WorkspaceFrame extends StatelessWidget {
  const WorkspaceFrame({
    super.key,
    required this.hackathonName,
    required this.title,
    required this.active,
    required this.counts,
    required this.onTab,
    required this.onHackathons,
    required this.child,
    this.projectTitle,
  });

  /// Short name for the breadcrumb, e.g. "Serverpod".
  final String hackathonName;

  /// Full name, shown large.
  final String title;

  /// The workspace this view belongs to; while a project is open, the one it
  /// was opened from.
  final WorkspaceTab active;

  /// The number beside each tab, where it has one.
  final Map<WorkspaceTab, int> counts;
  final ValueChanged<WorkspaceTab> onTab;
  final VoidCallback onHackathons;

  /// Set while a project is open: the breadcrumb's last level.
  final String? projectTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final gutter = workspaceGutter(box.maxWidth);
          return Padding(
            padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _breadcrumb(box.maxWidth),
                const SizedBox(height: 6),
                _identity(),
                const SizedBox(height: 10),
                const Divider(height: 1, color: rule),
                const SizedBox(height: 10),
                Expanded(child: child),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _breadcrumb(double width) {
    const style = TextStyle(fontSize: 12, color: muted);
    Widget crumb(String label, VoidCallback? onTap, {Key? key}) => InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(label, style: style),
      ),
    );
    const slash = Text('/', style: TextStyle(fontSize: 12, color: rule));
    final inProject = projectTitle != null;
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          BrandMark(compact: width < brandBreakpoint),
          const SizedBox(width: 20),
          crumb('Hackathons', onHackathons, key: const ValueKey('crumb-home')),
          slash,
          crumb(
            hackathonName,
            () => onTab(WorkspaceTab.overview),
            key: const ValueKey('crumb-hackathon'),
          ),
          slash,
          crumb(
            active.label,
            inProject ? () => onTab(active) : null,
            key: const ValueKey('crumb-workspace'),
          ),
          if (inProject) ...[
            slash,
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  projectTitle!,
                  key: const ValueKey('crumb-project'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _identity() => SizedBox(
    height: 44,
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            key: const ValueKey('hackathon-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              height: 1.2,
              letterSpacing: -.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 24),
        _Tabs(active: active, counts: counts, onTab: onTab),
      ],
    ),
  );
}

/// Primary navigation: large, filled when active, always visible.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.active,
    required this.counts,
    required this.onTab,
  });
  final WorkspaceTab active;
  final Map<WorkspaceTab, int> counts;
  final ValueChanged<WorkspaceTab> onTab;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EFEA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tab in WorkspaceTab.values)
          Semantics(
            selected: tab == active,
            button: true,
            child: InkWell(
              key: ValueKey('workspace-${tab.name}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onTab(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tab == active ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: tab == active
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: tab == active ? Colors.white : ink,
                      ),
                    ),
                    if (counts[tab] != null) ...[
                      const SizedBox(width: 7),
                      Text(
                        '${counts[tab]}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: tab == active
                              ? Colors.white.withValues(alpha: .85)
                              : muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
