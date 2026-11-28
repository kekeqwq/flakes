#include <dirent.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "lock-status.h"

static bool property(const char *root, const char *device, const char *name, char value[32]) {
	char path[512];
	int n = snprintf(path, sizeof(path), "%s/%s/%s", root, device, name);
	if (n < 0 || (size_t)n >= sizeof(path)) return false;
	FILE *file = fopen(path, "r");
	if (!file) return false;
	bool ok = fgets(value, 32, file) != NULL;
	fclose(file);
	if (ok) value[strcspn(value, "\r\n")] = '\0';
	return ok;
}

static void read_power_status(const char *root, const char *battery, char label[32]) {
	label[0] = '\0';
	unsigned total = 0, batteries = 0;
	bool plugged = false, charging = false, full = false;
	DIR *dir = opendir(root);
	if (!dir) return;
	struct dirent *entry;
	while ((entry = readdir(dir))) {
		const char *dev = entry->d_name;
		if (dev[0] == '.') continue;
		char value[32];
		if (property(root, dev, "scope", value) && !strcmp(value, "Device")) continue;
		if (!property(root, dev, "type", value)) continue;
		if (strcmp(value, "Battery")) {
			if (property(root, dev, "online", value) && !strcmp(value, "1")) plugged = true;
			continue;
		}
		if (battery && strcmp(dev, battery)) continue;
		if (property(root, dev, "status", value)) {
			charging |= !strcmp(value, "Charging");
			full |= !strcmp(value, "Full");
		}
		if (property(root, dev, "capacity", value)) {
			char *end;
			long level = strtol(value, &end, 10);
			if (end != value && !*end && level >= 0 && level <= 100) {
				total += level;
				batteries++;
			}
		}
	}
	closedir(dir);
	if (batteries) {
		const char *source = charging ? "Charging" : plugged || full ? "Plugged in" : "On battery";
		snprintf(label, 32, "%u%%  %s", total / batteries, source);
	}
}

static const char *power_status(void) {
	static time_t sampled = -1;
	static char label[32];
	struct timespec now;
	if (clock_gettime(CLOCK_MONOTONIC, &now) == 0) {
		if (sampled == now.tv_sec) return label;
		sampled = now.tv_sec;
	}
	read_power_status("/sys/class/power_supply", getenv("KEKE_SWAYLOCK_BATTERY"), label);
	return label;
}

void draw_lock_status(cairo_t *cr, double center, double date_baseline, double radius) {
	const double pi = 3.14159265358979323846;
	double size = radius * 0.14;
	double y = date_baseline + radius * 0.20;
	cairo_save(cr);
	cairo_new_path(cr);
	cairo_set_line_width(cr, size * 0.085);
	cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
	cairo_set_line_join(cr, CAIRO_LINE_JOIN_ROUND);
	cairo_move_to(cr, center - size * 0.30, y);
	cairo_line_to(cr, center - size * 0.30, y - size * 0.20);
	cairo_arc(cr, center, y - size * 0.20, size * 0.30, pi, 2 * pi);
	cairo_line_to(cr, center + size * 0.30, y);
	cairo_rectangle(cr, center - size * 0.47, y, size * 0.94, size * 0.65);
	cairo_stroke(cr);
	cairo_arc(cr, center, y + size * 0.28, size * 0.07, 0, 2 * pi);
	cairo_fill(cr);
	const char *text = power_status();
	if (*text) {
		cairo_text_extents_t extents;
		cairo_set_font_size(cr, radius * 0.105);
		cairo_text_extents(cr, text, &extents);
		cairo_move_to(cr, center - extents.x_bearing - extents.width / 2, y + size * 1.75);
		cairo_show_text(cr, text);
	}
	cairo_restore(cr);
}
