#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <time.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <sys/wait.h>
#include <unistd.h>
#include "key-auth-client.h"

static pid_t worker = -1;
static uint64_t retry_after, attempt_started;
#ifndef KEY_AUTH_ATTEMPT_MSEC
#define KEY_AUTH_ATTEMPT_MSEC 45000
#endif

static uint64_t monotonic_msec(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) < 0) return UINT64_MAX;
    return (uint64_t)now.tv_sec * 1000 + (uint64_t)now.tv_nsec / 1000000;
}

bool key_auth_expired(void) {
    uint64_t now = monotonic_msec();
    return worker > 0 && (now == UINT64_MAX || now - attempt_started >= KEY_AUTH_ATTEMPT_MSEC);
}

int key_auth_start(void) {
    uint64_t now = monotonic_msec();
    if (now == UINT64_MAX || now < retry_after) return -1;
    retry_after = now + 1000;
    key_auth_stop();
    attempt_started = now;
    int channel[2];
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, channel) < 0) return -1;
    int credentials = 1;
    if (setsockopt(channel[0], SOL_SOCKET, SO_PASSCRED, &credentials, sizeof(credentials)) < 0) {
        close(channel[0]); close(channel[1]); return -1;
    }
    pid_t parent = getpid();
    worker = fork();
    if (worker < 0) {
        close(channel[0]);
        close(channel[1]);
        return -1;
    }
    if (worker == 0) {
        /* Only async-signal-safe operations between fork and exec (the locker
         * may already have OpenMP threads). The worker cannot retain Wayland,
         * password pipes, readiness FDs or the screen-lock singleton FD 9. */
        if (prctl(PR_SET_PDEATHSIG, SIGTERM) < 0 || getppid() != parent) _exit(1);
        if (channel[1] != 3 && dup2(channel[1], 3) < 0) _exit(1);
        if (fcntl(3, F_SETFD, 0) < 0 || close_range(4, ~0U, 0) < 0) _exit(1);
        char *const arguments[] = { "@keyAuthHelper@", NULL };
        execv(arguments[0], arguments);
        _exit(1);
    }
    close(channel[1]);
    int flags = fcntl(channel[0], F_GETFL);
    if (flags < 0 || fcntl(channel[0], F_SETFL, flags | O_NONBLOCK) < 0) {
        close(channel[0]);
        key_auth_stop();
        return -1;
    }
    return channel[0];
}

int key_auth_read(int fd) {
    char message;
    _Alignas(struct cmsghdr) char control[CMSG_SPACE(sizeof(struct ucred))];
    struct iovec data = { .iov_base = &message, .iov_len = 1 };
    struct msghdr packet = { .msg_iov = &data, .msg_iovlen = 1,
        .msg_control = control, .msg_controllen = sizeof(control) };
    ssize_t count = recvmsg(fd, &packet, MSG_DONTWAIT);
    if (count < 0 && (errno == EAGAIN || errno == EINTR)) return 0;
    if (count != 1 || message != 'K' || (packet.msg_flags & (MSG_TRUNC | MSG_CTRUNC))) return -1;
    for (struct cmsghdr *header = CMSG_FIRSTHDR(&packet); header;
            header = CMSG_NXTHDR(&packet, header)) {
        if (header->cmsg_level == SOL_SOCKET && header->cmsg_type == SCM_CREDENTIALS
                && header->cmsg_len == CMSG_LEN(sizeof(struct ucred))) {
            const struct ucred *sender = (const struct ucred *)CMSG_DATA(header);
            return sender->pid == worker && sender->uid == getuid() ? 1 : -1;
        }
    }
    return -1;
}

void key_auth_stop(void) {
    if (worker > 0) {
        kill(worker, SIGTERM);
        while (waitpid(worker, NULL, 0) < 0 && errno == EINTR) {}
        worker = -1;
    }
}
