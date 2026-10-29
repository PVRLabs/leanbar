"""Build a disposable AppKit harness from the actual Host implementation."""
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
races = "--races" in sys.argv
work = root / (".build/refresh races" if races else ".build/ui smoke")
work.mkdir(parents=True, exist_ok=True)
for name in ("action.json", "fail", "delay", "mode", "history.json", "producer-started", "action-delay"):
    (work / name).unlink(missing_ok=True)
fixture = work / "fixture.py"
fixture.write_text('''#!/usr/bin/python3
import json, pathlib, shlex, sys, time
root = pathlib.Path(__file__).parent
if len(sys.argv) > 1:
    if (root / 'action-delay').exists():
        time.sleep(1)
    (root / 'action.json').write_text(json.dumps(sys.argv[1:]))
    history = root / 'history.json'
    entries = json.loads(history.read_text()) if history.exists() else []
    history.write_text(json.dumps(entries + [sys.argv[1:]]))
elif (root / 'fail').exists():
    print('deliberate fixture failure', file=sys.stderr)
    sys.exit(7)
else:
    (root / 'producer-started').touch()
    if (root / 'delay').exists():
        time.sleep(.6)
    if (root / 'mode').exists():
        print('title=🟢 Fixture\\n---')
        print('Changed status\\nInserted label')
        print('Different action | shell=' + shlex.quote(str(pathlib.Path(__file__).resolve())) +
              ' param1=wrong terminal=false refresh=true')
        sys.exit(0)
    print('Fixture\\n---')
    print(('Action recorded' if (root / 'action.json').exists() else 'Waiting for action') + ' | color=green')
    print('Record argv | shell=' + shlex.quote(str(pathlib.Path(__file__).resolve())) +
          ' param1="literal space" param2="$(printf unsafe)" terminal=false refresh=true')
''')
fixture.chmod(0o755)
source = (root / "src/main.swift").read_text().split("let args = CommandLine.arguments\n")[0]
source += (root / ("tests/refresh-races.swift" if races else "tests/ui-smoke.swift")).read_text()
(work / "main.swift").write_text(source)
subprocess.run(["swiftc", "-O", "-module-cache-path", str(root / ".build/module-cache"),
                str(work / "main.swift"), "-o", str(work / "LeanBarUISmoke")], check=True)
p = subprocess.run([str(work / "LeanBarUISmoke"), str(fixture), str(root / "src/invoke.py")],
                   text=True, capture_output=True, timeout=45)
history_file = work / "history.json"
evidence = dict(status=p.returncode, stdout=p.stdout, stderr=p.stderr,
                argv_history=json.loads(history_file.read_text()) if history_file.exists() else [])
output = work / "result.json"
output.write_text(json.dumps(evidence, indent=2))
print(json.dumps(evidence, indent=2))
assert p.returncode == 0
expected = ["literal space", "$(printf unsafe)"]
assert json.loads((work / "action.json").read_text()) == expected
if races:
    assert json.loads((work / "history.json").read_text()) == [expected, expected]
