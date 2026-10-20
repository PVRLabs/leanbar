"""Focused parser and execution checks with harmless fixtures only."""
import importlib.util
import os
import tempfile
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('invoke', ROOT / 'src/invoke.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
BINARY = ROOT / '.build/LeanBar.app/Contents/MacOS/LeanBar'

class Checks(unittest.TestCase):
    def test_example_parses(self):
        text = subprocess.run([str(ROOT / 'examples/menu.sh')], check=True, capture_output=True).stdout
        self.assertIn(b'desk | color=blue', text)
        parsed = subprocess.run([str(BINARY), '--check'], input=text, capture_output=True)
        self.assertEqual(parsed.returncode, 0, parsed.stderr)
        self.assertIn(b'3 actions', parsed.stdout)

    def test_battery_states(self):
        with tempfile.TemporaryDirectory() as directory:
            pmset = Path(directory) / 'pmset'
            pmset.write_text('#!/bin/sh\nprintf \'%s\\n\' "$TEST_BATTERY"\n')
            pmset.chmod(0o755)
            for script in ('menu.sh', 'menu-preview.sh'):
                for state, percent, label in (
                    ('charging', 85, 'charging'), ('not charging', 85, 'not charging'),
                    ('charged', 100, 'charged'), ('discharging', 85, 'unplugged'),
                    ('discharging', 15, 'low'),
                ):
                    with self.subTest(script=script, state=state, percent=percent):
                        env = dict(os.environ, PATH=f'{directory}:' + os.environ['PATH'],
                                   TEST_BATTERY=f"Now drawing from 'AC Power'\n"
                                   f' -InternalBattery-0  {percent}%; {state}; (no estimate) present: true')
                        result = subprocess.run(['/bin/bash', str(ROOT / 'examples' / script)],
                                                env=env, text=True, capture_output=True, check=True)
                        battery = next(line for line in result.stdout.splitlines()
                                       if line.startswith('Battery '))
                        self.assertEqual(battery.split(' | ')[0], f'Battery {percent}% · {label}')

    def test_invalid_contracts(self):
        for row in ('Bad | shell=/bin/echo terminal=true',
                    'Bad | shell=/bin/echo terminal=false param2=gap',
                    'Bad | unknown=true', 'Bad | shell="unclosed'):
            with self.subTest(row=row):
                result = subprocess.run([str(BINARY), '--check'], input='Title\n---\n' + row,
                                        text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0)

    def test_parameter_keys_are_canonical(self):
        for key in ('param01', 'param001', 'param+1', 'param0', 'param-1',
                    'param', 'param１', 'param999999999999999999999999999999'):
            for command in ('shell=/bin/echo terminal=false ', ''):
                with self.subTest(key=key, command=command):
                    text = f'Example\n---\nRun | {command}{key}=hello\n'
                    result = subprocess.run([str(BINARY), '--check'], input=text,
                                            text=True, capture_output=True)
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertIn(key, result.stderr)

    def test_canonical_parameters_parse_in_any_order(self):
        parameters = ' '.join(f'param{i}=value{i}' for i in range(12, 0, -1))
        text = f'Example\n---\nRun | shell=/bin/echo terminal=false {parameters}\n'
        result = subprocess.run([str(BINARY), '--check'], input=text,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('1 actions', result.stdout)

    def test_literal_argv(self):
        result = helper.invoke([sys.executable, '-c', 'import sys; print(repr(sys.argv[1:]))',
                                'a b', '$(touch never)'])
        self.assertEqual(result['status'], 0)
        self.assertEqual(result['stdout'].strip(), "['a b', '$(touch never)']")

    def test_failure(self):
        result = helper.invoke(['/bin/sh', '-c', 'echo failure >&2; exit 7'])
        self.assertEqual(result['status'], 7)
        self.assertEqual(result['stderr'].strip(), 'failure')

    def test_timeout_and_descendants(self):
        result = helper.invoke(['/bin/sh', '-c', 'sleep 10 & echo $!; wait'], timeout=.2)
        self.assertEqual(result['error'], 'timeout')
        child = int(result['stdout'].strip())
        probe = subprocess.run(['/bin/ps', '-o', 'stat=', '-p', str(child)],
                               check=False, capture_output=True, text=True)
        self.assertIn(probe.returncode, (0, 1), probe.stderr)
        self.assertTrue(not probe.stdout.strip() or probe.stdout.strip().startswith('Z'))

    def test_output_bound(self):
        result = helper.invoke([sys.executable, '-c', "import os; os.write(1,b'x'*1000000)"], limit=1024)
        self.assertEqual(result['error'], 'output limit')
        self.assertLessEqual(len(result['stdout']), 1024)

    def test_invalid_interval(self):
        result = subprocess.run([str(BINARY), '/bin/echo', 'inf'], capture_output=True)
        self.assertEqual(result.returncode, 2)

if __name__ == '__main__':
    unittest.main()
