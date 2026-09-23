import 'dart:convert';

enum Dimension {
  structuralDistinctiveness(
    'Structural distinctiveness',
    'How unusual is the project’s arrangement of ideas?',
  ),
  evidenceInspectability(
    'Evidence inspectability',
    'How directly can its existing artifacts be inspected?',
  ),
  humanWorldGrounding(
    'Human-world grounding',
    'How much does it connect to observed human behavior?',
  ),
  interactionDepth(
    'Interaction depth',
    'How much can a person explore, respond, and revise?',
  ),
  systemOrchestration(
    'System orchestration',
    'How many coordinated technical responsibilities are involved?',
  ),
  creativeScope(
    'Creative scope',
    'How broad is the range of creative activities?',
  ),
  audienceCentrality(
    'Audience centrality',
    'How central is the audience to the project’s idea?',
  );

  const Dimension(this.label, this.description);
  final String label;
  final String description;
}

enum CompetitionLens {
  standout(
    'Standout',
    Dimension.structuralDistinctiveness,
    Dimension.evidenceInspectability,
  ),
  humanLoop(
    'Human Loop',
    Dimension.humanWorldGrounding,
    Dimension.interactionDepth,
  ),
  systemDepth(
    'System Depth',
    Dimension.systemOrchestration,
    Dimension.creativeScope,
  ),
  audienceReality(
    'Audience Reality',
    Dimension.audienceCentrality,
    Dimension.humanWorldGrounding,
  );

  const CompetitionLens(this.label, this.x, this.y);
  final String label;
  final Dimension x;
  final Dimension y;
}

enum SubmissionLens { idea, integration }

enum NodeKind {
  human,
  surface,
  model,
  transformation,
  external,
  signal,
  artifact,
}

enum Topology { flow, hub, loop, layers }

enum EdgeKind { flow, feedback }

class SemanticNode {
  const SemanticNode(this.id, this.label, this.kind, this.detail);
  final String id;
  final String label;
  final NodeKind kind;
  final String detail;

  factory SemanticNode.fromJson(Map<String, dynamic> json) => SemanticNode(
    json['id'] as String,
    json['label'] as String,
    NodeKind.values.byName(json['kind'] as String),
    json['detail'] as String,
  );
}

class SemanticEdge {
  const SemanticEdge(
    this.from,
    this.to, {
    this.kind = EdgeKind.flow,
    this.label = '',
  });
  final String from;
  final String to;
  final EdgeKind kind;
  final String label;

  factory SemanticEdge.fromJson(Map<String, dynamic> json) => SemanticEdge(
    json['from'] as String,
    json['to'] as String,
    kind: EdgeKind.values.byName(json['kind'] as String? ?? 'flow'),
    label: json['label'] as String? ?? '',
  );
}

/// Meaning and connectivity only. Layout hints never contain coordinates.
class SemanticGraph {
  const SemanticGraph({
    required this.topology,
    required this.description,
    required this.nodes,
    required this.edges,
    this.focus,
  });
  final Topology topology;
  final String description;
  final List<SemanticNode> nodes;
  final List<SemanticEdge> edges;
  final String? focus;

  factory SemanticGraph.fromJson(Map<String, dynamic> json) {
    final graph = SemanticGraph(
      topology: Topology.values.byName(json['topology'] as String),
      description: json['description'] as String,
      nodes: List.unmodifiable(
        (json['nodes'] as List).map((n) => SemanticNode.fromJson(n)),
      ),
      edges: List.unmodifiable(
        (json['edges'] as List).map((e) => SemanticEdge.fromJson(e)),
      ),
      focus: json['focus'] as String?,
    );
    graph.validate();
    return graph;
  }

  void validate() {
    final ids = nodes.map((n) => n.id).toSet();
    if (ids.isEmpty || ids.length != nodes.length) {
      throw const FormatException('Graph node IDs must be unique and nonempty');
    }
    if ((focus != null && !ids.contains(focus)) ||
        (topology == Topology.hub && focus == null)) {
      throw const FormatException('Hub requires a valid focus node');
    }
    for (final e in edges) {
      if (!ids.contains(e.from) || !ids.contains(e.to) || e.from == e.to) {
        throw const FormatException('Edge must connect two existing nodes');
      }
    }
    // Forward edges must be acyclic. Iteration is explicit, never silently lost.
    final remaining = {...ids};
    while (remaining.isNotEmpty) {
      final roots = remaining
          .where(
            (id) => !edges.any(
              (e) =>
                  e.kind == EdgeKind.flow &&
                  e.to == id &&
                  remaining.contains(e.from),
            ),
          )
          .toList();
      if (roots.isEmpty) {
        throw const FormatException('Mark cyclic edges as feedback');
      }
      remaining.removeAll(roots);
    }
    final reached = {nodes.first.id};
    var previous = 0;
    while (previous != reached.length) {
      previous = reached.length;
      for (final e in edges) {
        if (reached.contains(e.from) || reached.contains(e.to)) {
          reached.addAll([e.from, e.to]);
        }
      }
    }
    if (reached.length != ids.length) {
      throw const FormatException('Disconnected graph');
    }
  }
}

class ProjectRepresentation {
  const ProjectRepresentation({
    required this.id,
    required this.title,
    required this.creator,
    required this.summary,
    required this.dimensions,
    required this.dimensionNotes,
    required this.idea,
    required this.integration,
  });
  final String id;
  final String title;
  final String creator;
  final String summary;
  final Map<Dimension, double> dimensions;
  final Map<Dimension, String> dimensionNotes;
  final SemanticGraph idea;
  final SemanticGraph integration;
  SemanticGraph graph(SubmissionLens lens) =>
      lens == SubmissionLens.idea ? idea : integration;

  factory ProjectRepresentation.fromJson(Map<String, dynamic> json) {
    final dimensions = <Dimension, double>{};
    final notes = <Dimension, String>{};
    for (final d in Dimension.values) {
      final raw = (json['competitionDimensions'] as Map)[d.name] as Map;
      final value = (raw['value'] as num).toDouble();
      if (!value.isFinite || value < 0 || value > 1) {
        throw FormatException('Invalid dimension: ${d.name}');
      }
      dimensions[d] = value;
      notes[d] = raw['note'] as String;
    }
    return ProjectRepresentation(
      id: json['id'] as String,
      title: json['title'] as String,
      creator: json['creator'] as String,
      summary: json['summary'] as String,
      dimensions: Map.unmodifiable(dimensions),
      dimensionNotes: Map.unmodifiable(notes),
      idea: SemanticGraph.fromJson(json['idea']),
      integration: SemanticGraph.fromJson(json['integration']),
    );
  }
}

List<ProjectRepresentation> parseProjects(String source) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  final projects = (json['projects'] as List)
      .map((p) => ProjectRepresentation.fromJson(p))
      .toList();
  if (projects.map((p) => p.id).toSet().length != projects.length) {
    throw const FormatException('Duplicate project IDs');
  }
  return List.unmodifiable(projects);
}
