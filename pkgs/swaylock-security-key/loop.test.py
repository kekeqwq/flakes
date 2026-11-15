"""ASan regression against the actual upstream loop.c: callbacks must defer
removing their own watch until loop_poll() finishes traversing fd_events."""
import os
from pathlib import Path
import shlex
import subprocess as sp
import sys
import tempfile

loop, log, include, compiler = sys.argv[1:]
driver = r'''
#include <assert.h>
#include <poll.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include "loop.h"
static struct loop *eventloop;
static bool dead, unsafe;
static void closed(int fd, short mask, void *data) {
    (void)mask; (void)data;
    if (unsafe) { loop_remove_fd(eventloop, fd); close(fd); }
    else dead = true;
}
static void untouched(int fd, short mask, void *data) {
    (void)fd; (void)mask; (void)data; assert(false);
}
int main(int argc, char **argv) {
    assert(argc == 2); unsafe = !strcmp(argv[1], "unsafe");
    eventloop = loop_create(); assert(eventloop);
    int password[2]; assert(pipe(password) == 0);
    loop_add_fd(eventloop, password[0], POLLIN, untouched, NULL);
    for (int i = 0; i < 200; ++i) {
        int channel[2]; assert(pipe(channel) == 0);
        dead = false;
        loop_add_fd(eventloop, channel[0], POLLIN, closed, NULL);
        close(channel[1]);
        loop_poll(eventloop);
        assert(dead);
        assert(loop_remove_fd(eventloop, channel[0]));
        close(channel[0]);
    }
    close(password[0]); close(password[1]); loop_destroy(eventloop);
    return 0;
}
'''
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    (root / "driver.c").write_text(driver)
    flags = shlex.split(sp.check_output(["pkg-config", "--cflags", "--libs", "wayland-client"], text=True))
    binary = root / "loop-regression"
    sp.run([compiler, "-std=c11", "-g", "-O1", "-fsanitize=address", "-fno-omit-frame-pointer",
            "-I" + include, str(root / "driver.c"), loop, log, *flags, "-o", str(binary)], check=True)
    env = os.environ | {"ASAN_OPTIONS": "detect_leaks=0:abort_on_error=1"}
    old = sp.run([str(binary), "unsafe"], env=env, capture_output=True, timeout=10)
    assert old.returncode != 0 and b"heap-use-after-free" in old.stderr, "Old callback deletion did not reproduce the UAF"
    sp.run([str(binary), "deferred"], env=env, check=True, timeout=10)
print("actual event loop: unsafe deletion UAF reproduced; 200 deferred EOF/retry cycles PASS under ASan")
