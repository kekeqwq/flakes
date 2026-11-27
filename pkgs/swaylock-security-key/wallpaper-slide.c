#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <unistd.h>
#include "loop.h"
#include "swaylock.h"
#include "wallpaper-slide.h"

enum { SLIDE_INTERVAL_MS = 8000 };
static const char *helper, *mode;
static pid_t worker;
static int frame_fd = -1, previous_fd = -1;
static cairo_surface_t *frame;

cairo_surface_t *wallpaper_slide_image(void) {
	return frame;
}

static cairo_status_t read_png(void *data, unsigned char *buffer, unsigned len) {
	int fd = *(int *)data;
	while (len) {
		ssize_t n = read(fd, buffer, len);
		if (n < 0 && errno == EINTR) continue;
		if (n <= 0) return CAIRO_STATUS_READ_ERROR;
		buffer += n;
		len -= n;
	}
	return CAIRO_STATUS_SUCCESS;
}

static void present(struct swaylock_state *state, cairo_surface_t *next, int fd) {
	if (frame) cairo_surface_destroy(frame);
	if (previous_fd >= 0) close(previous_fd);
	frame = next;
	previous_fd = fd;
	struct swaylock_surface *surface;
	wl_list_for_each(surface, &state->surfaces, link) {
		surface->slide_dirty = true;
	}
	damage_state(state);
}

static void collect(void *data) {
	struct swaylock_state *state = data;
	int status;
	pid_t result = waitpid(worker, &status, WNOHANG);
	if (result == 0 || (result < 0 && errno == EINTR)) {
		loop_add_timer(state->eventloop, 100, collect, state);
		return;
	}
	worker = 0;
	bool success = result > 0 && WIFEXITED(status) && WEXITSTATUS(status) == 0;
	off_t size = success ? lseek(frame_fd, 0, SEEK_END) : -1;
	// No suitable frame (including decoder failure): leave the displayed
	// image untouched. Never select a fallback image on the slideshow path.
	if (size > 0 && size <= 64 * 1024 * 1024 && lseek(frame_fd, 0, SEEK_SET) == 0) {
		cairo_surface_t *next = cairo_image_surface_create_from_png_stream(read_png, &frame_fd);
		if (cairo_surface_status(next) == CAIRO_STATUS_SUCCESS) {
			present(state, next, frame_fd);
			frame_fd = -1;
		} else {
			cairo_surface_destroy(next);
		}
	}
	if (frame_fd >= 0) close(frame_fd);
	frame_fd = -1;
}

static void advance(void *data) {
	struct swaylock_state *state = data;
	loop_add_timer(state->eventloop, SLIDE_INTERVAL_MS, advance, state);
	if (worker) return;
	frame_fd = memfd_create("swaylock-slide", MFD_CLOEXEC);
	if (frame_fd < 0) return;
	posix_spawn_file_actions_t actions;
	if (posix_spawn_file_actions_init(&actions) != 0) goto failed;
	int rc = previous_fd < 0 ?
		posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0) :
		posix_spawn_file_actions_adddup2(&actions, previous_fd, STDIN_FILENO);
	if (previous_fd >= 0 && lseek(previous_fd, 0, SEEK_SET) < 0) rc = errno;
	if (!rc) rc = posix_spawn_file_actions_adddup2(&actions, frame_fd, STDOUT_FILENO);
	// The decoder must not inherit the Wayland socket, auth channels or flock.
	if (!rc) rc = posix_spawn_file_actions_addclosefrom_np(&actions, 3);
	char *const argv[] = {(char *)helper, (char *)mode, NULL};
	if (!rc) rc = posix_spawn(&worker, helper, &actions, NULL, argv, environ);
	posix_spawn_file_actions_destroy(&actions);
	if (!rc) {
		loop_add_timer(state->eventloop, 100, collect, state);
		return;
	}
failed:
	worker = 0;
	close(frame_fd);
	frame_fd = -1;
}

void wallpaper_slide_start(struct swaylock_state *state) {
	helper = getenv("KEKE_LOCK_SLIDE_HELPER");
	mode = getenv("KEKE_LOCK_SLIDE_MODE");
	if (helper && helper[0] == '/' && mode &&
			(!strcmp(mode, "random") || !strcmp(mode, "sfw"))) {
		loop_add_timer(state->eventloop, SLIDE_INTERVAL_MS, advance, state);
	}
}

void wallpaper_slide_stop(void) {
	if (worker) kill(worker, SIGTERM);
	if (frame_fd >= 0) close(frame_fd);
	if (previous_fd >= 0) close(previous_fd);
	if (frame) cairo_surface_destroy(frame);
}
