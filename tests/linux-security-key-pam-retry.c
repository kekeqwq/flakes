#define _GNU_SOURCE
/* Isolated PAM lifecycle regression; no production PAM edits and no secrets. */
#include <security/pam_appl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <time.h>

static int no_input(int count, const struct pam_message **messages,
        struct pam_response **responses, void *data) {
    (void)data;
    for (int i = 0; i < count; ++i)
        if (messages[i]->msg_style != PAM_TEXT_INFO && messages[i]->msg_style != PAM_ERROR_MSG)
            return PAM_CONV_ERR;
    *responses = calloc((size_t)count, sizeof(**responses));
    return *responses ? PAM_SUCCESS : PAM_BUF_ERR;
}
static void copy(const char *from, const char *to) {
    FILE *in = fopen(from, "r"), *out = fopen(to, "w");
    if (!in || !out) exit(2);
    char buffer[4096]; size_t size;
    while ((size = fread(buffer, 1, sizeof(buffer), in)))
        if (fwrite(buffer, 1, size, out) != size) exit(2);
    fclose(in); fclose(out);
}
int main(int argc, char **argv) {
    if (argc != 6) return 2;
    /* confdir, wrong-list, right-list, mutable-authfile, persistent|reopen */
    if (prctl(PR_SET_DUMPABLE, 0) < 0) return 2;
    const struct pam_conv conversation = { .conv = no_input };
    pam_handle_t *handle = NULL;
    int status = PAM_AUTH_ERR;
    for (int attempt = 0; attempt < 2; ++attempt) {
        copy(argv[attempt == 0 ? 2 : 3], argv[4]);
        if (!handle) {
            status = pam_start_confdir("flakes-retry", "keke", &conversation, argv[1], &handle);
            if (status != PAM_SUCCESS) return 3;
        }
        struct timespec before, after;
        clock_gettime(CLOCK_MONOTONIC, &before);
        status = pam_authenticate(handle, 0);
        clock_gettime(CLOCK_MONOTONIC, &after);
        printf("attempt=%d status=%d elapsed=%.3f\n", attempt + 1, status,
               (double)(after.tv_sec - before.tv_sec) + (after.tv_nsec - before.tv_nsec) / 1e9);
        fflush(stdout);
        if (!strcmp(argv[5], "reopen")) { pam_end(handle, status); handle = NULL; }
    }
    if (handle) pam_end(handle, status);
    return 0;
}
