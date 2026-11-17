#import "ctk-lock-state.h"
#include <spawn.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#import <dispatch/dispatch.h>

static BOOL ProbeFidoVerification(BOOL authenticate) {
    Trace(ProbeLockDiagnostic().UTF8String);
    Trace(ProbeGlobalLockDiagnostic().UTF8String);
    if (authenticate && !ProbeNativeLocked()) { Trace("hardware_gate_CLOSED_no_auth"); return NO; }
    NSString *root = NSBundle.mainBundle.bundlePath;
    NSString *worker = [root stringByAppendingPathComponent:@"Contents/MacOS/ctk-fido-worker"];
    NSString *mapping = [root stringByAppendingPathComponent:@"Contents/Resources/public-u2f-keys"];
    char *arguments[] = {(char *)worker.fileSystemRepresentation,
        authenticate ? "--verify" : "--self-check", (char *)mapping.fileSystemRepresentation, NULL};
    posix_spawn_file_actions_t actions;
    if (posix_spawn_file_actions_init(&actions)) return NO;
    for (int fd = 0; fd <= 2; fd++) {
        if (posix_spawn_file_actions_addopen(&actions, fd, "/dev/null", fd == 0 ? O_RDONLY : O_WRONLY, 0)) {
            posix_spawn_file_actions_destroy(&actions); return NO;
        }
    }
    pid_t child = -1;
    char *environment[] = {"PATH=/usr/bin:/bin", "LANG=C", NULL};
    int spawned = posix_spawn(&child, arguments[0], &actions, NULL, arguments, environment);
    posix_spawn_file_actions_destroy(&actions);
    if (spawned || child <= 1) { Trace("hardware_worker_spawn_FAILED"); return NO; }
    Trace(authenticate ? "hardware_worker_started_after_native_lock" : "sandbox_fido_selfcheck_started_no_auth");
    double deadline = NSProcessInfo.processInfo.systemUptime + (authenticate ? 20 : 5);
    BOOL terminating = NO, killed = NO;
    int status = 0;
    for (;;) {
        pid_t result = waitpid(child, &status, WNOHANG);
        if (result == child) break;
        if (result < 0 && errno == EINTR) continue;
        if (result < 0) { Trace("hardware_worker_wait_FAILED"); return NO; }
        // Until waitpid reaps this exact child, even an exited child retains its PID.
        double now = NSProcessInfo.processInfo.systemUptime;
        if (!terminating && ((authenticate && !ProbeNativeLocked()) || now >= deadline)) {
            Trace(authenticate ? "hardware_worker_cancelled_unlock_or_timeout" : "sandbox_loader_timeout_no_auth");
            kill(child, SIGTERM); terminating = YES; deadline = now + 1;
        } else if (terminating && !killed && now >= deadline) {
            kill(child, SIGKILL); killed = YES; deadline = now + 2;
        } else if (killed && now >= deadline) {
            Trace("hardware_worker_reap_pending_auth_CANCELLED");
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                int ignored;
                while (waitpid(child, &ignored, 0) < 0 && errno == EINTR) {}
            });
            return NO; // Never keep the CTK caller waiting on an uninterruptible child.
        }
        [NSThread sleepForTimeInterval:0.05];
    }
    if (WIFEXITED(status)) {
        char event[64];
        snprintf(event, sizeof(event), authenticate ? "hardware_worker_exit_%d" : "sandbox_worker_exit_%d", WEXITSTATUS(status));
        Trace(event);
    }
    if (!authenticate) {
        Trace(!terminating && WIFEXITED(status) && WEXITSTATUS(status) == 0 ?
            "sandbox_fido_selfcheck_PASSED_no_auth" : "sandbox_fido_selfcheck_FAILED_no_auth");
        return NO; // A successful loader self-check is NEVER hardware authorization.
    }
    BOOL verified = !terminating && WIFEXITED(status) && WEXITSTATUS(status) == 0 && ProbeNativeLocked();
    if (verified) Trace("hardware_signature_VERIFIED_native_signature_STILL_DENIED");
    else Trace("hardware_not_verified_native_signature_DENIED");
    return verified;
}
