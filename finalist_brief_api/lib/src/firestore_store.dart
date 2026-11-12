import 'package:finalist_brief_shared/finalist_brief_shared.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';

import 'fixture.dart';
import 'store.dart';

/// A [Store] in Cloud Firestore (Native mode, the `(default)` database).
///
/// Collections: `submissions/<slug>`, `analyses/<submissionId>`,
/// `briefs/<auto id>` and `meta/seed` (the fixture hash). On Cloud Run it
/// authenticates as the service's runtime service account, which needs
/// `roles/datastore.user`.
class FirestoreStore implements Store {
  FirestoreStore(this._firestore);

  /// Connects with Application Default Credentials: the runtime service
  /// account on Cloud Run, or `gcloud auth application-default login` locally.
  factory FirestoreStore.connect(String projectId) =>
      FirestoreStore(Firestore(settings: Settings(projectId: projectId)));

  final Firestore _firestore;

  Future<void> close() => _firestore.terminate();

  @override
  Future<List<Submission>> listSubmissions() async {
    final snapshot = await _firestore
        .collection('submissions')
        .orderBy('sortOrder')
        .get();
    return [for (final doc in snapshot.docs) Submission.fromJson(doc.data())];
  }

  @override
  Future<List<SubmissionAnalysis>> listAnalyses(String promptVersion) async {
    final snapshot = await _firestore
        .collection('analyses')
        .orderBy('submissionId')
        .get();
    return [
      for (final doc in snapshot.docs)
        if (doc.data()['promptVersion'] == promptVersion)
          SubmissionAnalysis.fromJson(doc.data()),
    ];
  }

  @override
  Future<String?> seedVersion() async {
    final snapshot = await _firestore.collection('meta').doc('seed').get();
    if (!snapshot.exists) return null;
    return snapshot.data()?['hash'] as String?;
  }

  @override
  Future<void> seed(Fixture fixture) async {
    final batch = _firestore.batch();
    for (final s in fixture.submissions) {
      batch.set(_firestore.collection('submissions').doc(s.slug), s.toJson());
    }
    for (final a in fixture.analyses) {
      batch.set(
        _firestore.collection('analyses').doc('${a.submissionId}'),
        a.toJson(),
      );
    }
    batch.set(_firestore.collection('meta').doc('seed'), {
      'hash': fixture.hash,
    });
    await batch.commit();
  }

  @override
  Future<Brief> insertBrief(Brief brief) async {
    final ref = _firestore.collection('briefs').doc();
    await ref.set({
      ...brief.toJson(),
      // Numeric copy of createdAt, so briefs can be ordered by time.
      'createdAtMs': brief.createdAt.millisecondsSinceEpoch,
    });
    return brief.withId(ref.id);
  }

  @override
  Future<Brief?> findBrief(String id) async {
    final snapshot = await _firestore.collection('briefs').doc(id).get();
    final data = snapshot.data();
    return snapshot.exists && data != null
        ? Brief.fromJson({...data, 'id': snapshot.id})
        : null;
  }

  @override
  Future<List<Brief>> newestBriefs(int limit) async {
    final snapshot = await _firestore
        .collection('briefs')
        .orderBy('createdAtMs', descending: true)
        .limit(limit)
        .get();
    return [
      for (final doc in snapshot.docs)
        Brief.fromJson({...doc.data(), 'id': doc.id}),
    ];
  }
}
