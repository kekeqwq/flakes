#define _POSIX_C_SOURCE 200809L
/* Private child of the locker, not a desktop unlock daemon. FD 3 is a fresh,
 * anonymous, credential-checked socketpair from this exact locker. */
#include <fcntl.h>
#include <pwd.h>
#include <security/pam_appl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <unistd.h>

static int touch_only(int count, const struct pam_message **messages,
        struct pam_response **responses, void *data) {
    (void)data;
    if (count <= 0) return PAM_CONV_ERR;
    for (int i = 0; i < count; ++i) {
        /* Never answer a PIN, password, or interactive acknowledgement. */
        if (messages[i]->msg_style != PAM_TEXT_INFO &&
                messages[i]->msg_style != PAM_ERROR_MSG) return PAM_CONV_ERR;
    }
    *responses = calloc((size_t)count, sizeof(**responses));
    return *responses ? PAM_SUCCESS : PAM_BUF_ERR;
}

int main(void) {
    struct passwd *user = getpwuid(getuid());
    if (!user || getuid() != geteuid() || getgid() != getegid() ||
            prctl(PR_SET_DUMPABLE, 0) < 0) return 1;
    char *username = strdup(user->pw_name);
    if (!username || fcntl(3, F_SETFD, FD_CLOEXEC) < 0) return 1;
    const struct pam_conv conversation = { .conv = touch_only };
    pam_handle_t *handle = NULL;
    int status = pam_start("swaylock-key", username, &conversation, &handle);
    if (status != PAM_SUCCESS) return 1;
    status = pam_authenticate(handle, 0);
    if (status == PAM_SUCCESS) status = pam_acct_mgmt(handle, 0);
    int ended = pam_end(handle, status);
    if (status == PAM_SUCCESS && ended == PAM_SUCCESS) {
        /* The compositor-facing locker consumes the proof; we never signal
         * it. All failed attempts exit, closing every FIDO/PAM descriptor at
         * process teardown before the parent starts a fresh transaction. */
        return write(3, "K", 1) == 1 ? 0 : 1;
    }
    return 1;
}
