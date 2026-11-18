"""Display only recognized sudo conversation prompts, never raw output."""

import os
import subprocess

PASSWORD_PROMPT = b'[keke-sudo-password]'
AUTH_COMPLETE = b'[keke-sudo-authorized]'
TOUCH_PROMPTS = (b'please touch the fido authenticator', b'please touch the device')


class SudoPrompt:
    def __init__(self, argv):
        self.process = subprocess.Popen(
            argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, env={**os.environ, 'LC_ALL': 'C'}, bufsize=0,
            start_new_session=True,
        )
        os.set_blocking(self.process.stdout.fileno(), False)
        self.state = 'checking'
        self.buffer = b''
        self.authorized = False

    def feed(self, chunk):
        self.buffer += chunk.lower()
        while True:
            matches = [(self.buffer.find(marker), marker, state) for state, markers in (
                ('password', (PASSWORD_PROMPT,)), ('touch', TOUCH_PROMPTS),
                ('working', (AUTH_COMPLETE,)),
            ) for marker in markers if marker in self.buffer]
            if not matches:
                self.buffer = self.buffer[-64:]
                break
            index, marker, state = min(matches)
            self.buffer = self.buffer[index + len(marker):]
            if state == 'working':
                self.authorized = True
            if not self.authorized or state == 'working':
                self.state = state
        return self.state

    def poll(self):
        # Bounded drain keeps GTK responsive even if a subprocess is noisy.
        for _ in range(8):
            try:
                data = os.read(self.process.stdout.fileno(), 4096)
            except BlockingIOError:
                break
            if not data:
                break
            self.feed(data)
        code = self.process.poll()
        if code is not None:
            self.finish()
            return 'done' if code == 0 else 'failed'
        return self.state

    def password(self, value):
        if self.state != 'password' or '\n' in value or '\r' in value:
            return False
        try:
            self.process.stdin.write(value.encode() + b'\n')
        except OSError:
            return False
        self.state = 'checking'
        return True

    def finish(self):
        self.process.stdin.close()
        self.process.stdout.close()

    def cancel(self):
        # Read any final authorization marker before deciding whether to stop.
        if self.poll() in ('done', 'failed'):
            return
        if not self.authorized:
            try:
                self.process.terminate()
            except PermissionError:
                # Authorization may have completed while the view was closing.
                pass
        self.finish()
