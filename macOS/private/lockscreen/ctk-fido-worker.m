// Signature verification only. No enrollment, account rights or native signatures.
#import "ctk-lock-state.h"
#import <os/log.h>
#include <security/pam_appl.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static BOOL secretPrompt = NO;
static int conversation(int n, const struct pam_message **messages,
                        struct pam_response **response, void *data) {
    (void)data;
    if (n <= 0 || n > 16 || !messages || !response) return PAM_CONV_ERR;
    for (int i = 0; i < n; i++) {
        if (!messages[i] || (messages[i]->msg_style != PAM_TEXT_INFO && messages[i]->msg_style != PAM_ERROR_MSG)) {
            secretPrompt = YES;
            os_log(OS_LOG_DEFAULT, "flakes_fido_secret_prompt_REJECTED");
            return PAM_CONV_ERR; // Never ask for or provide PIN/password.
        }
        if (messages[i]->msg_style == PAM_TEXT_INFO)
            os_log(OS_LOG_DEFAULT, "flakes_fido_information_touch_may_be_requested");
    }
    *response = calloc((size_t)n, sizeof(**response));
    return *response ? PAM_SUCCESS : PAM_BUF_ERR;
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        setbuf(stdout, NULL);
        if (argc == 2 && strcmp(argv[1], "--gate-check") == 0) {
            printf("{\"native_locked_gate\":%s,\"authentication_started\":false}\n", ProbeNativeLocked() ? "true" : "false");
            return 0;
        }
        BOOL moduleCheck = argc == 3 && strcmp(argv[1], "--module-check") == 0;
        // The separate loader check never creates a PAM handle or calls auth.
        if (!moduleCheck && !ProbeNativeLocked()) {
            printf("{\"gate_closed\":true,\"authentication_started\":false}\n");
            return 6;
        }
        if (argc != 3) return 2;
        void *pam = dlopen("/usr/lib/libpam.2.dylib", RTLD_NOW | RTLD_LOCAL);
        if (!pam) return 7;
        int (*start)(const char *, const char *, const struct pam_conv *, pam_handle_t **) = dlsym(pam, "pam_start");
        int (*end)(pam_handle_t *, int) = dlsym(pam, "pam_end");
        if (!start || !end) return 7;
        void *module = dlopen(moduleCheck ? argv[2] : argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!module) { printf("{\"module_load_failed\":true}\n"); return 7; }
        int (*authenticate)(pam_handle_t *, int, int, const char **) = dlsym(module, "pam_sm_authenticate");
        if (!authenticate) return 7;
        if (moduleCheck) {
            printf("{\"module_load_ok\":true,\"authentication_started\":false}\n");
            return 0;
        }
        struct pam_conv conv = { conversation, NULL };
        pam_handle_t *handle = NULL;
        if (start("other", "keke", &conv, &handle) != PAM_SUCCESS) return 8;
        char authfile[2048];
        if (snprintf(authfile, sizeof(authfile), "authfile=%s", argv[2]) >= (int)sizeof(authfile)) {
            end(handle, PAM_ABORT); return 8;
        }
        const char *options[] = { authfile, "origin=pam://keke-flakes", "appid=pam://keke-flakes",
            "userpresence=1", "pinverification=0", "userverification=0", "cue" };
        if (!ProbeNativeLocked()) { end(handle, PAM_ABORT); return 6; }
        int result = authenticate(handle, 0, 7, options);
        int ended = end(handle, result);
        BOOL stillLocked = ProbeNativeLocked();
        BOOL verified = result == PAM_SUCCESS && ended == PAM_SUCCESS && !secretPrompt && stillLocked;
        printf("{\"fido_signature_verified\":%s,\"pam_result\":%d,\"pam_end_result\":%d,\"secret_prompt_rejected\":%s,\"still_locked\":%s}\n",
               verified ? "true" : "false", result, ended, secretPrompt ? "true" : "false", stillLocked ? "true" : "false");
        return verified ? 0 : 9;
    }
}
