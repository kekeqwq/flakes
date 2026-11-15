"""Check the actual worker with fake PAM; these are lifecycle/fail-closed tests,
not a substitute for real hardware/PAM and compositor regression."""
import os
from pathlib import Path
import select
import subprocess as sp
import sys
import tempfile

source, include, compiler = sys.argv[1:]
mock = r'''
#include <security/pam_appl.h>
#include <stdlib.h>
#include <string.h>
static const struct pam_conv *conversation;
int pam_start(const char *service, const char *user, const struct pam_conv *conv, pam_handle_t **handle) {
    if (strcmp(service, "swaylock-key") || strcmp(user, "root") == 0) abort();
    conversation = conv; *handle = (pam_handle_t *)conv; return PAM_SUCCESS;
}
int pam_authenticate(pam_handle_t *handle, int flags) {
    (void)handle; (void)flags;
    const char *mode = getenv("MOCK_PAM_CASE");
    if (!strcmp(mode, "deny")) return PAM_AUTH_ERR;
    if (!strcmp(mode, "pin")) {
        const struct pam_message message = { .msg_style = PAM_PROMPT_ECHO_OFF, .msg = "PIN" };
        const struct pam_message *messages[] = { &message };
        struct pam_response *responses = NULL;
        return conversation->conv(1, messages, &responses, conversation->appdata_ptr);
    }
    return PAM_SUCCESS;
}
int pam_acct_mgmt(pam_handle_t *handle, int flags) {
    (void)handle; (void)flags;
    return !strcmp(getenv("MOCK_PAM_CASE"), "expired") ? PAM_ACCT_EXPIRED : PAM_SUCCESS;
}
int pam_end(pam_handle_t *handle, int status) { (void)handle; (void)status; return PAM_SUCCESS; }
'''
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    (root / "mock.c").write_text(mock)
    sp.run([compiler, "-std=c11", "-Wall", "-Wextra", "-Werror", "-I" + include,
            source, str(root / "mock.c"), "-o", str(root / "worker")], check=True)
    for mode in ("success", "deny", "expired", "pin"):
        read, write = os.pipe()
        if read == 3:
            old = read
            read = os.dup(read)
            os.close(old)
        os.dup2(write, 3)
        if write != 3:
            os.close(write)
        child = sp.Popen([str(root / "worker")], pass_fds=(3,),
                         env=os.environ | {"MOCK_PAM_CASE": mode})
        os.close(3)
        try:
            ready = bool(select.select([read], [], [], 1.3)[0])
            if mode == "success":
                assert ready and os.read(read, 2) == b"K"
                assert child.wait(timeout=2) == 0
            else:
                assert ready and os.read(read, 2) == b"", mode
                assert child.wait(timeout=2) != 0, mode
        finally:
            if child.poll() is None:
                child.terminate()
            child.wait(timeout=2)
            os.close(read)
print("worker auth/account/PIN-failure gating: PASS")
