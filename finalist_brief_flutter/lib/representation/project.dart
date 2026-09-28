import 'dart:convert';

/// Competition dimensions. `{sponsor}` is replaced by the competition's
/// sponsor technology, so the same grammar serves any hackathon.
enum Dimension {
  ideaDistinctiveness(
    'Idea distinctiveness',
    'How unusual is the project’s conceptual structure within this field?',
  ),
  integrationDepth(
    'Integration depth',
    'How much working implementation stands behind the idea?',
  ),
  sponsorCentrality(
    '{sponsor} centrality',
    'How much of the core function depends on {sponsor}?',
  ),
  sponsorEvidence(
    '{sponsor} evidence',
    'How clearly can the use of {sponsor} be verified?',
  );

  const Dimension(this._label, this._description);
  final String _label;
  final String _description;
  String label(String sponsor) => _label.replaceAll('{sponsor}', sponsor);
  String description(String sponsor) =>
      _description.replaceAll('{sponsor}', sponsor);
}

enum CompetitionLens {
  ideaIntegration(
    'Idea × Integration',
    Dimension.integrationDepth,
    Dimension.ideaDistinctiveness,
    'How unusual is the concept, and how much implementation stands behind it?',
    [
      'Unusual concept · lighter build',
      'Unusual concept · deeper build',
      'Familiar concept · lighter build',
      'Familiar concept · deeper build',
    ],
  ),
  sponsorTech(
    'Sponsor Tech',
    Dimension.sponsorCentrality,
    Dimension.sponsorEvidence,
    'How important is {sponsor} to the project, and how clearly can that use be verified?',
    [
      'Peripheral · easy to verify',
      'Central · easy to verify',
      'Peripheral · hard to verify',
      'Central · hard to verify',
    ],
  );

  const CompetitionLens(
    this.label,
    this.x,
    this.y,
    this._question,
    this.corners,
  );
  final String label;
  final Dimension x;
  final Dimension y;
  final String _question;

  /// Neutral descriptions of each corner: top-left, top-right, bottom-left,
  /// bottom-right. They describe combinations, never rank them.
  final List<String> corners;
  String question(String sponsor) => _question.replaceAll('{sponsor}', sponsor);
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

/// How Finalist Brief knows something, strongest first. The order is a trust
/// tier, not a calibrated probability, so no numeric confidence is stored.
enum EvidenceStatus {
  demonstrated('Demonstrated', 'Seen working in a recorded demo.'),
  foundInCode('Found in code', 'Located in the submitted source.'),
  described('Described', 'Stated by the team; not independently seen.'),
  inferred(
    'Inferred',
    'Finalist Brief’s structural reading; no direct source.',
  );

  const EvidenceStatus(this.label, this.meaning);
  final String label;
  final String meaning;
}

enum SourceKind { video, repo, writeup, notebook, site, image }

class Source {
  const Source(this.kind, this.label, {this.url, this.revision});
  final SourceKind kind;
  final String label;
  final String? url;

  /// A pinned commit for repository links, e.g. the last one before a
  /// deadline; links use the default branch when absent.
  final String? revision;

  factory Source.fromJson(Map<String, dynamic> json) => Source(
    SourceKind.values.byName(json['kind'] as String),
    json['label'] as String,
    url: json['url'] as String?,
    revision: json['rev'] as String?,
  );
}

/// A pointer into one of the project's [Source]s: a file path, a README
/// section, or a video timestamp.
class SourceRef {
  const SourceRef(this.source, {this.at, this.seconds, this.detail = ''});
  final String source;
  final String? at;
  final int? seconds;
  final String detail;

  factory SourceRef.fromJson(Map<String, dynamic> json) => SourceRef(
    json['source'] as String,
    at: json['at'] as String?,
    seconds: json['t'] as int?,
    detail: json['detail'] as String? ?? '',
  );
}

class EvidenceFrame {
  const EvidenceFrame(this.image, this.ref);
  final String image;
  final SourceRef ref;

  factory EvidenceFrame.fromJson(Map<String, dynamic> json) =>
      EvidenceFrame(json['image'] as String, SourceRef.fromJson(json));
}

/// Why Finalist Brief believes a node, edge or Idea ↔ Integration mapping
/// exists. Shared by all three so relationships can carry the same provenance.
class Evidence {
  const Evidence({
    required this.status,
    required this.note,
    this.refs = const [],
    this.frame,
  });
  final EvidenceStatus status;
  final String note;
  final List<SourceRef> refs;
  final EvidenceFrame? frame;

  static const unrecorded = Evidence(
    status: EvidenceStatus.inferred,
    note: 'No evidence has been recorded for this element.',
  );

  factory Evidence.fromJson(Map<String, dynamic> json) => Evidence(
    status: EvidenceStatus.values.byName(json['status'] as String),
    note: json['note'] as String,
    refs: List.unmodifiable(
      (json['refs'] as List? ?? const []).map((r) => SourceRef.fromJson(r)),
    ),
    frame: json['frame'] == null
        ? null
        : EvidenceFrame.fromJson(json['frame'] as Map<String, dynamic>),
  );

  /// A status may never claim more than its sources support.
  void validate(Map<String, Source> sources, String where) {
    final all = [...refs, if (frame != null) frame!.ref];
    for (final ref in all) {
      if (!sources.containsKey(ref.source)) {
        throw FormatException('$where cites unknown source ${ref.source}');
      }
    }
    if (note.trim().isEmpty) {
      throw FormatException('$where needs a one-line explanation');
    }
    SourceKind kind(SourceRef ref) => sources[ref.source]!.kind;
    final supported = switch (status) {
      EvidenceStatus.demonstrated => all.any(
        (r) => kind(r) == SourceKind.video && r.seconds != null,
      ),
      EvidenceStatus.foundInCode => all.any(
        (r) => kind(r) == SourceKind.repo && (r.at ?? '').isNotEmpty,
      ),
      EvidenceStatus.described => all.isNotEmpty,
      EvidenceStatus.inferred => true,
    };
    if (!supported) {
      throw FormatException('$where: ${status.name} lacks a supporting source');
    }
  }
}

class SemanticNode {
  const SemanticNode(
    this.id,
    this.label,
    this.kind,
    this.detail, {
    this.evidence,
  });
  final String id;
  final String label;
  final NodeKind kind;

  /// A short sublabel; empty when the title says enough.
  final String detail;
  final Evidence? evidence;

  factory SemanticNode.fromJson(Map<String, dynamic> json) => SemanticNode(
    json['id'] as String,
    json['label'] as String,
    NodeKind.values.byName(json['kind'] as String),
    json['detail'] as String? ?? '',
    evidence: json['evidence'] == null
        ? null
        : Evidence.fromJson(json['evidence'] as Map<String, dynamic>),
  );
}

class SemanticEdge {
  const SemanticEdge(
    this.from,
    this.to, {
    this.kind = EdgeKind.flow,
    this.label = '',
    this.evidence,
  });
  final String from;
  final String to;
  final EdgeKind kind;
  final String label;

  /// Relationships carry the same evidence model as nodes. The UI does not
  /// surface it yet; questions can already anchor to edges.
  final Evidence? evidence;

  factory SemanticEdge.fromJson(Map<String, dynamic> json) => SemanticEdge(
    json['from'] as String,
    json['to'] as String,
    kind: EdgeKind.values.byName(json['kind'] as String? ?? 'flow'),
    label: json['label'] as String? ?? '',
    evidence: json['evidence'] == null
        ? null
        : Evidence.fromJson(json['evidence'] as Map<String, dynamic>),
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

  SemanticNode node(String id) => nodes.singleWhere((n) => n.id == id);
  bool hasEdge(String from, String to) =>
      edges.any((e) => e.from == from && e.to == to);

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

/// A node or an edge in one of a project's two graphs.
class GraphRef {
  const GraphRef.node(this.lens, String this.node) : from = null, to = null;
  const GraphRef.edge(this.lens, String this.from, String this.to)
    : node = null;
  final SubmissionLens lens;
  final String? node;
  final String? from;
  final String? to;
  bool get isNode => node != null;

  factory GraphRef.fromJson(Map<String, dynamic> json) {
    final lens = SubmissionLens.values.byName(json['lens'] as String);
    final edge = json['edge'] as List?;
    return edge == null
        ? GraphRef.node(lens, json['node'] as String)
        : GraphRef.edge(lens, edge[0] as String, edge[1] as String);
  }

  @override
  bool operator ==(Object other) =>
      other is GraphRef &&
      other.lens == lens &&
      other.node == node &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(lens, node, from, to);
}

/// How the conceptual structure is realized. An empty [integration] list
/// records that no implementation counterpart was found — itself a finding.
class Correspondence {
  const Correspondence({
    required this.label,
    required this.idea,
    required this.integration,
    required this.evidence,
  });
  final String label;
  final List<String> idea;
  final List<String> integration;
  final Evidence evidence;

  Set<GraphRef> get refs => {
    for (final id in idea) GraphRef.node(SubmissionLens.idea, id),
    for (final id in integration) GraphRef.node(SubmissionLens.integration, id),
  };

  factory Correspondence.fromJson(Map<String, dynamic> json) => Correspondence(
    label: json['label'] as String,
    idea: List.unmodifiable(json['idea'] as List),
    integration: List.unmodifiable(json['integration'] as List),
    evidence: Evidence.fromJson(json['evidence'] as Map<String, dynamic>),
  );
}

enum QuestionKind {
  mismatch('Idea / Integration mismatch'),
  unclear('Unclear relationship'),
  unverified('Unverified claim'),
  implementation('Implementation question');

  const QuestionKind(this.label);
  final String label;
}

/// A question for the team that follows from a specific structural or
/// evidence gap. The first anchor is a node and carries the visual hint.
class JudgeQuestion {
  const JudgeQuestion({
    required this.id,
    required this.kind,
    required this.question,
    required this.basis,
    required this.anchors,
    this.refs = const [],
  });
  final String id;
  final QuestionKind kind;
  final String question;
  final String basis;
  final List<GraphRef> anchors;
  final List<SourceRef> refs;
  GraphRef get hint => anchors.first;

  factory JudgeQuestion.fromJson(Map<String, dynamic> json) => JudgeQuestion(
    id: json['id'] as String,
    kind: QuestionKind.values.byName(json['kind'] as String),
    question: json['question'] as String,
    basis: json['basis'] as String,
    anchors: List.unmodifiable(
      (json['anchors'] as List).map((a) => GraphRef.fromJson(a)),
    ),
    refs: List.unmodifiable(
      (json['refs'] as List? ?? const []).map((r) => SourceRef.fromJson(r)),
    ),
  );
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
    this.sources = const {},
    this.mapping = const [],
    this.questions = const [],
    this.generated = false,
  });
  final String id;
  final String title;
  final String creator;
  final String summary;

  /// Produced by the automatic pipeline (tool/deep_review) rather than
  /// written by hand; the UI says so, since no person checked it.
  final bool generated;
  final Map<Dimension, double> dimensions;
  final Map<Dimension, String> dimensionNotes;
  final SemanticGraph idea;
  final SemanticGraph integration;
  final Map<String, Source> sources;
  final List<Correspondence> mapping;
  final List<JudgeQuestion> questions;

  SemanticGraph graph(SubmissionLens lens) =>
      lens == SubmissionLens.idea ? idea : integration;

  /// Everything a node corresponds to across both graphs, including itself.
  Set<GraphRef> related(GraphRef ref) => {
    ref,
    for (final c in mapping)
      if (c.refs.contains(ref)) ...c.refs,
  };

  List<Correspondence> mappingFor(GraphRef ref) =>
      mapping.where((c) => c.refs.contains(ref)).toList();

  List<JudgeQuestion> questionsAt(GraphRef ref) =>
      questions.where((q) => q.hint == ref).toList();

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
    final project = ProjectRepresentation(
      id: json['id'] as String,
      title: json['title'] as String,
      creator: json['creator'] as String,
      summary: json['summary'] as String,
      generated: (json['origin'] as Map?)?['method'] == 'generated',
      dimensions: Map.unmodifiable(dimensions),
      dimensionNotes: Map.unmodifiable(notes),
      idea: SemanticGraph.fromJson(json['idea']),
      integration: SemanticGraph.fromJson(json['integration']),
      sources: Map.unmodifiable({
        for (final e in (json['sources'] as Map? ?? const {}).entries)
          e.key as String: Source.fromJson(e.value as Map<String, dynamic>),
      }),
      mapping: List.unmodifiable(
        (json['mapping'] as List? ?? const []).map(
          (m) => Correspondence.fromJson(m),
        ),
      ),
      questions: List.unmodifiable(
        (json['questions'] as List? ?? const []).map(
          (q) => JudgeQuestion.fromJson(q),
        ),
      ),
    );
    project.validate();
    return project;
  }

  bool _exists(GraphRef ref) {
    final graph = this.graph(ref.lens);
    return ref.isNode
        ? graph.nodes.any((n) => n.id == ref.node)
        : graph.hasEdge(ref.from!, ref.to!);
  }

  void validate() {
    for (final lens in SubmissionLens.values) {
      final graph = this.graph(lens);
      for (final n in graph.nodes) {
        n.evidence?.validate(sources, '$id ${lens.name}.${n.id}');
      }
      for (final e in graph.edges) {
        e.evidence?.validate(sources, '$id ${lens.name}.${e.from}>${e.to}');
      }
    }
    for (final c in mapping) {
      if (c.idea.isEmpty || !c.refs.every(_exists)) {
        throw FormatException('$id mapping "${c.label}" is dangling');
      }
      c.evidence.validate(sources, '$id mapping "${c.label}"');
    }
    if (questions.map((q) => q.id).toSet().length != questions.length) {
      throw FormatException('$id has duplicate question IDs');
    }
    for (final q in questions) {
      if (q.anchors.isEmpty || !q.hint.isNode || !q.anchors.every(_exists)) {
        throw FormatException('$id question ${q.id} has invalid anchors');
      }
      if (!q.question.trim().endsWith('?') || q.basis.trim().isEmpty) {
        throw FormatException(
          '$id question ${q.id} needs a question and basis',
        );
      }
      for (final r in q.refs) {
        if (!sources.containsKey(r.source)) {
          throw FormatException('$id question ${q.id} cites ${r.source}');
        }
      }
    }
  }
}

class Competition {
  const Competition({
    required this.title,
    required this.sponsorTech,
    required this.provenance,
    required this.projects,
  });
  final String title;
  final String sponsorTech;
  final String provenance;
  final List<ProjectRepresentation> projects;
}

Competition parseCompetition(String source) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  final projects = (json['projects'] as List)
      .map((p) => ProjectRepresentation.fromJson(p))
      .toList();
  if (projects.map((p) => p.id).toSet().length != projects.length) {
    throw const FormatException('Duplicate project IDs');
  }
  final meta = json['competition'] as Map<String, dynamic>? ?? const {};
  return Competition(
    title: meta['title'] as String? ?? '',
    sponsorTech: meta['sponsorTech'] as String? ?? 'Sponsor tech',
    provenance: json['provenance'] as String? ?? '',
    projects: List.unmodifiable(projects),
  );
}

List<ProjectRepresentation> parseProjects(String source) =>
    parseCompetition(source).projects;
