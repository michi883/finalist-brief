"""Verifier ID matching, retry and fail-closed behaviour.

    cd tool/deep_review && python3 -m unittest discover tests

No model is called: the verifier's replies are stubbed.
"""

import json
import os
import shutil
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import ground  # noqa: E402

MAPPINGS = [
    'mapping “Offline-first → online client only”',
    'mapping “Stir logged → reply text, no tool”',
    'mapping “Ferment temperatures → seeded note”',
    'mapping “Tide data → hour-based mock”',
]


class FakeContext:
    frame_paths = {}

    def file_lines(self, path):
        return [f'line {i}' for i in range(1, 30)]


def claim(cid):
    return (cid, {'note': f'note for {cid}'},
            [{'source': 'repo', 'at': 'lib/a.dart#L2-L4', 'detail': 'x'}])


def result(rid, code='yes'):
    return {'id': rid, 'demo': 'na', 'code': code, 'reason': 'r'}


class MatchIds(unittest.TestCase):
    def test_mapping_id_variants(self):
        # The IDs the verifier actually returned for root-radar.
        matched, unmatched = ground.match_ids(
            ['mapping-offline', 'mapping-stir', 'mapping-ferment-temp', 'mapping-tide'], MAPPINGS)
        self.assertEqual(unmatched, [])
        self.assertEqual(matched, {
            'mapping-offline': MAPPINGS[0], 'mapping-stir': MAPPINGS[1],
            'mapping-ferment-temp': MAPPINGS[2], 'mapping-tide': MAPPINGS[3]})

    def test_punctuation_and_quote_variants(self):
        matched, _ = ground.match_ids(
            ['mapping "Tide data → hour-based mock"', 'Integration.App'],
            [MAPPINGS[3], 'integration.app'])
        self.assertEqual(matched['mapping "Tide data → hour-based mock"'], MAPPINGS[3])
        self.assertEqual(matched['Integration.App'], 'integration.app')

    def test_question_ids(self):
        cids = ['question q1', 'question q2']
        matched, unmatched = ground.match_ids(['q1', 'question q2'], cids)
        self.assertEqual(matched, {'q1': 'question q1', 'question q2': 'question q2'})
        self.assertEqual(unmatched, [])

    def test_full_id_without_its_kind_word(self):
        # What the verifier returned for the-bolt-chef: the label alone.
        cid = 'mapping “List insight → text & image, no audio”'
        matched, unmatched = ground.match_ids(
            ['List insight → text & image, no audio', 'text & image'], [cid, MAPPINGS[0]])
        self.assertEqual(matched, {'List insight → text & image, no audio': cid})
        self.assertEqual(unmatched, ['text & image'])

    def test_ambiguous_or_unknown_ids_stay_unmatched(self):
        # "online" fits two claims; "harvest" fits none; a claim is taken once.
        cids = [MAPPINGS[0], 'mapping “Online shop → online orders”']
        matched, unmatched = ground.match_ids(
            ['mapping-online', 'mapping-harvest', MAPPINGS[0], MAPPINGS[0]], cids)
        self.assertEqual(matched, {MAPPINGS[0]: MAPPINGS[0]})
        self.assertEqual(unmatched, ['mapping-online', 'mapping-harvest', MAPPINGS[0]])


class Verify(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        patches = [
            mock.patch.object(ground, 'workspace', lambda sid, *p: os.path.join(self.dir, *p)),
            mock.patch.object(ground, 'route', lambda stage: {'provider': 'stub', 'model': 'stub'}),
        ]
        os.makedirs(os.path.join(self.dir, 'llm'))
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        self.addCleanup(shutil.rmtree, self.dir)

    def run_verify(self, replies, cids):
        calls = []

        def ask(sid, name, stage, system, content, schema):
            calls.append((name, [b['text'] for b in content if b['type'] == 'text'
                                 and b['text'].startswith('\n### Claim')]))
            return {'results': replies[len(calls) - 1]}

        log = []
        with mock.patch.object(ground, 'ask', ask):
            verdicts = ground.verify('s', [claim(c) for c in cids], FakeContext(), log)
        return verdicts, calls, log

    def test_variant_ids_get_verdicts_without_retry(self):
        verdicts, calls, log = self.run_verify(
            [[result('mapping-offline'), result('mapping-tide', 'no')]], [MAPPINGS[0], MAPPINGS[3]])
        self.assertEqual(len(calls), 1)
        self.assertEqual(verdicts[MAPPINGS[0]]['code'], 'yes')
        self.assertEqual(verdicts[MAPPINGS[3]]['code'], 'no')
        self.assertFalse(any(v.get('missing') for v in verdicts.values()))
        self.assertIn(f'verifier ID “mapping-offline” read as {MAPPINGS[0]}', log)

    def test_retry_recovers_a_missing_verdict(self):
        verdicts, calls, log = self.run_verify(
            [[result(MAPPINGS[0])], [result(MAPPINGS[1])]], MAPPINGS[:2])
        self.assertEqual([c[0] for c in calls], ['verify', 'verify-retry'])
        # The retry sends only the claim that had no verdict.
        self.assertEqual(len(calls[1][1]), 1)
        self.assertIn(MAPPINGS[1], calls[1][1][0])
        self.assertEqual(verdicts[MAPPINGS[1]]['code'], 'yes')
        self.assertFalse(verdicts[MAPPINGS[1]].get('missing'))

    def test_missing_after_retry_fails_closed(self):
        verdicts, calls, log = self.run_verify(
            [[result(MAPPINGS[0]), result('something-else')], []], MAPPINGS[:2])
        self.assertEqual(len(calls), 2)
        missing = verdicts[MAPPINGS[1]]
        self.assertTrue(missing['missing'])
        self.assertEqual((missing['demo'], missing['code']), ('no', 'no'))
        self.assertIn('verifier IDs matching no claim: something-else', log)
        self.assertTrue(any('treated as refuted' in n and MAPPINGS[1] in n for n in log))
        # Never stored, so a later run asks again.
        with open(os.path.join(self.dir, 'llm', 'verdicts.json')) as f:
            store = json.load(f)
        self.assertEqual(len(store), 1)

    def test_stored_verdicts_are_not_resent(self):
        self.run_verify([[result(MAPPINGS[0])]], MAPPINGS[:1])
        verdicts, calls, _ = self.run_verify([], MAPPINGS[:1])
        self.assertEqual(calls, [])
        self.assertEqual(verdicts[MAPPINGS[0]]['code'], 'yes')


@unittest.skipUnless(os.path.exists(os.path.join(ground.stage_path('root-radar', 'draft'))),
                     'needs the cached root-radar run')
class Grounding(unittest.TestCase):
    """Fail-closed through the whole grounding stage, on a cached review."""

    def test_no_verdicts_lower_every_claim_and_drop_questions(self):
        out = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, out)
        os.makedirs(os.path.join(out, 'llm'))
        real_stage_path = ground.stage_path

        def stage_path(sid, name):
            return os.path.join(out, f'{name}.json') if name in ('grounded', 'provenance') \
                else real_stage_path(sid, name)

        with mock.patch.object(ground, 'ask', lambda *a: {'results': []}), \
                mock.patch.object(ground, 'workspace', lambda sid, *p: os.path.join(out, *p)), \
                mock.patch.object(ground, 'stage_path', stage_path), \
                mock.patch('builtins.print'):
            ground.main('root-radar')
        with open(os.path.join(out, 'grounded.json')) as f:
            grounded = json.load(f)
        with open(os.path.join(out, 'provenance.json')) as f:
            provenance = json.load(f)
        statuses = [n['evidence']['status'] for lens in ('idea', 'integration')
                    for n in grounded[lens]['nodes']] + [m['evidence']['status'] for m in grounded['mapping']]
        self.assertNotIn('demonstrated', statuses)
        self.assertNotIn('foundInCode', statuses)
        self.assertTrue(provenance['lowered'])
        self.assertTrue(any('no verdict after retry' in n for n in provenance['verifier']))
        # Questions without a verdict are dropped; one always remains.
        self.assertEqual(len(grounded['questions']), 1)
        self.assertTrue(all('no verdict from the verifier' in d
                            for d in provenance['dropped'] if d.startswith('question')))


if __name__ == '__main__':
    unittest.main()
