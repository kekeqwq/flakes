"""Private-pipe/fail-closed/lifecycle checks with a fake (not installed) worker."""
import os
from pathlib import Path
import subprocess as sp
import sys
import tempfile
import time

source, header, compiler = sys.argv[1:]
worker = r'''
#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
int main(void) {
    if (fcntl(9, F_GETFD) >= 0 || fcntl(10, F_GETFD) >= 0) return 2;
    const char *mode = getenv("MOCK_CLIENT_CASE");
    if (!strcmp(mode, "parentdeath")) {
        printf("%ld\n", (long)getpid()); fflush(stdout); sleep(30); return 0;
    }
    if (!strcmp(mode, "spoof")) {
        pid_t child = fork();
        if (child < 0) return 3;
        if (child == 0) _exit(write(3, "K", 1) == 1 ? 0 : 4);
        return waitpid(child, NULL, 0) > 0 ? 0 : 5;
    }
    if (!strcmp(mode, "closed")) return 0;
    if (!strcmp(mode, "sleep") || !strcmp(mode, "watchdog")) { sleep(30); return 0; }
    return write(3, !strcmp(mode, "valid") ? "K" : "X", 1) == 1 ? 0 : 3;
}
'''
driver = r'''
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
#include "key-auth-client.h"
int main(void) {
    int sentinel = open("/dev/null", O_RDONLY);
    if (sentinel < 0 || dup2(sentinel, 9) < 0 || dup2(sentinel, 10) < 0) return 1;
    int fd = key_auth_start(); if (fd < 0) return 2;
    const char *mode = getenv("MOCK_CLIENT_CASE");
    if (!strcmp(mode, "parentdeath")) { for (;;) pause(); }
    struct pollfd item = { .fd = fd, .events = POLLIN };
    int waiting = !strcmp(mode, "sleep") || !strcmp(mode, "watchdog");
    int ready = poll(&item, 1, waiting ? 150 : 2500);
    int result = ready > 0 ? key_auth_read(fd) : 0;
    if (!strcmp(mode, "watchdog") && !key_auth_expired()) return 6;
    key_auth_stop(); close(fd);
    int status;
    if (waitpid(-1, &status, WNOHANG) != -1 || errno != ECHILD) return 3;
    int expected = !strcmp(mode, "valid") ? 1 : waiting ? 0 : -1;
    return result == expected ? 0 : 4;
}
'''
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    (root / "worker.c").write_text(worker)
    (root / "driver.c").write_text(driver)
    (root / "key-auth-client.c").write_text(Path(source).read_text().replace("@keyAuthHelper@", str(root / "worker")))
    (root / "key-auth-client.h").write_text(Path(header).read_text())
    for filename, sources in (("worker", ["worker.c"]), ("driver", ["driver.c", "key-auth-client.c"])):
        sp.run([compiler, "-std=c11", "-Wall", "-Wextra", "-Werror", "-DKEY_AUTH_ATTEMPT_MSEC=50", "-I" + directory,
                *[str(root / s) for s in sources], "-o", str(root / filename)], check=True)
    for mode in ("valid", "invalid", "spoof", "closed", "sleep", "watchdog"):
        sp.run([str(root / "driver")], env=os.environ | {"MOCK_CLIENT_CASE": mode}, check=True, timeout=4)
    parent = sp.Popen([str(root / "driver")], env=os.environ | {"MOCK_CLIENT_CASE": "parentdeath"},
                      stdout=sp.PIPE, text=True)
    try:
        child = int(parent.stdout.readline().strip())
        parent.kill()
        parent.wait(timeout=2)
        for _ in range(100):
            status = Path(f"/proc/{child}/stat")
            try:
                state = status.read_text().split(")", 1)[1].split()[0]
            except FileNotFoundError:
                break
            if state == "Z":
                break
            time.sleep(.02)
        else:
            raise AssertionError("worker survived its locker parent")
    finally:
        if parent.poll() is None:
            parent.kill()
            parent.wait()
print("private channel/EOF/invalid proof/spoofed sender/FD isolation/watchdog/reaping/parent death: PASS")
