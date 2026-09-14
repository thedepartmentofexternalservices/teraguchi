"""Static profile checks; no devices, permissions, host or input injection."""
import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('modifier_check', ROOT / 'scripts/test/check-flame-modifier-profile.py')
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class ModifierProfileTest(unittest.TestCase):
    def setUp(self):
        self.profile = CHECK.load_json(ROOT / 'tests/input/fixtures/modifiers-physical-identity.json')
        self.baseline = CHECK.load_json(ROOT / 'tests/input/fixtures/flame-smoke-classic-shortcuts.json')

    def test_identity_preserves_all_nine_ordered_sequences(self):
        result = CHECK.analyze(self.profile, self.baseline)
        self.assertEqual(len(result['cases']), 9)
        self.assertFalse(result['hardware_qualified'])
        self.assertFalse(result['runtime_profile_applied'])
        for case, original in zip(result['cases'], self.baseline['cases']):
            self.assertEqual(case['physical_key_events'], original['expected_host_key_events'])

    def test_blanket_command_to_control_rejected(self):
        for side in ('LEFT', 'RIGHT'):
            self.profile['mapping']['KEY_' + side + 'META'] = 'KEY_' + side + 'CTRL'
        with self.assertRaisesRegex(ValueError, 'unreachable.*LEFTMETA.*RIGHTMETA'):
            CHECK.analyze(self.profile, self.baseline)

    def test_collapsing_right_option_loses_mark_in(self):
        self.profile['mapping']['KEY_RIGHTALT'] = 'KEY_LEFTALT'
        with self.assertRaisesRegex(ValueError, 'RIGHTALT'):
            CHECK.analyze(self.profile, self.baseline)

    def test_collapsing_control_sides_loses_mark_out(self):
        self.profile['mapping']['KEY_RIGHTCTRL'] = 'KEY_LEFTCTRL'
        with self.assertRaisesRegex(ValueError, 'RIGHTCTRL'):
            CHECK.analyze(self.profile, self.baseline)

    def test_control_command_swap_substitutes_once_and_preserves_audio_chord(self):
        # Test feasibility only; this is not the default or an applied preference.
        for side in ('LEFT', 'RIGHT'):
            ctrl, meta = 'KEY_' + side + 'CTRL', 'KEY_' + side + 'META'
            self.profile['mapping'][ctrl], self.profile['mapping'][meta] = meta, ctrl
        result = CHECK.analyze(self.profile, self.baseline)
        audio = next(case for case in result['cases'] if case['id'] == 'audio_monitoring')
        self.assertEqual([event['key'] for event in audio['physical_key_events'][:4]],
                         ['KEY_LEFTSHIFT', 'KEY_LEFTMETA', 'KEY_LEFTCTRL', 'KEY_A'])
        mark_out = next(case for case in result['cases'] if case['id'] == 'mark_out')
        self.assertEqual(mark_out['physical_key_events'][0]['key'], 'KEY_RIGHTMETA')

    def test_incomplete_modifier_map_rejected(self):
        del self.profile['mapping']['KEY_RIGHTMETA']
        with self.assertRaises(ValueError):
            CHECK.analyze(self.profile, self.baseline)

    def test_unknown_or_non_modifier_target_rejected(self):
        for target in ('KEY_A', 'KEY_CTRL', None, [], 42):
            with self.subTest(target=target), self.assertRaises(ValueError):
                self.profile['mapping']['KEY_LEFTCTRL'] = target
                CHECK.analyze(self.profile, self.baseline)

    def test_source_does_not_accept_extra_keys(self):
        self.profile['mapping']['KEY_A'] = 'KEY_LEFTCTRL'
        with self.assertRaises(ValueError):
            CHECK.analyze(self.profile, self.baseline)

    def test_duplicate_json_fields_rejected(self):
        with self.assertRaises(ValueError):
            CHECK.unique_object([('mapping', {}), ('mapping', {})])

    def test_boolean_event_value_rejected(self):
        self.baseline['cases'][0]['expected_host_key_events'][0]['value'] = True
        with self.assertRaises(ValueError):
            CHECK.analyze(self.profile, self.baseline)

    def test_wrong_release_order_rejected(self):
        events = self.baseline['cases'][-1]['expected_host_key_events']
        events[-1], events[-2] = events[-2], events[-1]
        with self.assertRaises(ValueError):
            CHECK.analyze(self.profile, self.baseline)

    def test_duplicate_down_and_missing_up_rejected(self):
        original = copy.deepcopy(self.baseline)
        for events in ([{'key': 'KEY_A', 'value': 1}],
                       [{'key': 'KEY_A', 'value': 1}, {'key': 'KEY_A', 'value': 1}]):
            with self.subTest(events=events), self.assertRaises(ValueError):
                self.baseline = copy.deepcopy(original)
                self.baseline['cases'][0]['expected_host_key_events'] = events
                CHECK.analyze(self.profile, self.baseline)

    def test_fixture_cannot_claim_hardware_pass(self):
        self.baseline['status'] = 'PASS'
        with self.assertRaises(ValueError):
            CHECK.analyze(self.profile, self.baseline)

    def test_invalid_schema_and_duplicate_cases_rejected(self):
        self.baseline['cases'].append(copy.deepcopy(self.baseline['cases'][0]))
        with self.assertRaises(ValueError):
            CHECK.analyze(self.profile, self.baseline)
        self.profile['schema'] = 'runtime'
        with self.assertRaises(ValueError):
            CHECK.validate_profile(self.profile)


if __name__ == '__main__':
    unittest.main()
