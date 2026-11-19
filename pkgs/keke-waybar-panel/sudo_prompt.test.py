import runpy
import sys
import time

Prompt = runpy.run_path(sys.argv[1])['SudoPrompt']


def wait(prompt, state):
    for _ in range(200):
        if prompt.poll() == state:
            return
        time.sleep(0.01)
    raise AssertionError(f'expected {state}')


p = Prompt([sys.executable, '-c', '''
import sys
print('Please touch the FIDO authenticator.', flush=True)
print('[keke-sudo-password]', end='', file=sys.stderr, flush=True)
assert sys.stdin.readline() == 'fixture-only\\n'
print('[keke-sudo-authorized]', file=sys.stderr)
'''])
wait(p, 'password')
assert not p.password('no\nnewline')
assert p.password('fixture-only')
wait(p, 'done')
assert p.authorized

p = Prompt([sys.executable, '-c', '''
import time
print('Please touch the device.', flush=True)
time.sleep(20)
'''])
wait(p, 'touch')
assert not p.password('fixture-only')
p.cancel()
assert p.process.wait(timeout=1) != 0

p = Prompt([sys.executable, '-c', 'raise SystemExit(1)'])
assert p.feed(b'[keke-sudo-pass') == 'checking'
assert p.feed(b'word]') == 'password'
assert p.feed(b'[keke-sudo-authorized]') == 'working'
assert p.feed(b'[keke-sudo-password]') == 'working'
wait(p, 'failed')
p = Prompt([sys.executable, '-c', "print('[keke-sudo-authorized]'); raise SystemExit(5)"])
wait(p, 'source-kept')
print('Inline sudo prompts: key cue, fallback, cancellation and failure PASS')
