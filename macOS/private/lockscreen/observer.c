/* Diagnostic only: observes PAM service entry and NEVER authenticates. */
#include <security/pam_appl.h>
#include <security/pam_modules.h>
#include <os/log.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdio.h>
#include <time.h>

static void observe(pam_handle_t *pamh) {
    const char *path = "/var/run/flakes-lockscreen-observer.expiry";
    struct stat st;
    long long expiry = 0;
    time_t now = time(NULL);
    if (lstat(path, &st) != 0 || !S_ISREG(st.st_mode) ||
        st.st_uid != 0 || (st.st_mode & 022) != 0)
        return;
    FILE *file = fopen(path, "r");
    if (!file) return;
    int parsed = fscanf(file, "%lld", &expiry);
    fclose(file);
    /* A stale/malformed state never produces unbounded monitoring. */
    if (parsed != 1 || now < 0 || expiry < now || expiry > now + 180)
        return;
    const void *item = NULL;
    char service[80] = "unknown";
    if (pam_get_item(pamh, PAM_SERVICE, &item) == PAM_SUCCESS && item)
        snprintf(service, sizeof(service), "%.79s", (const char *)item);
    os_log_t log = os_log_create("com.keke.flakes.lock-observer", "pam-entry");
    os_log_with_type(log, OS_LOG_TYPE_DEFAULT,
                    "pam_entry service=%{public}s pid=%{public}d euid=%{public}u",
                    service, getpid(), geteuid());
    os_release(log);
}

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags,
                                  int argc, const char **argv) {
    (void)flags; (void)argc; (void)argv;
    observe(pamh);
    return PAM_IGNORE;
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags,
                             int argc, const char **argv) {
    (void)pamh; (void)flags; (void)argc; (void)argv;
    return PAM_IGNORE;
}
