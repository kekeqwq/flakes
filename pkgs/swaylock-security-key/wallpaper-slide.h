#ifndef WALLPAPER_SLIDE_H
#define WALLPAPER_SLIDE_H

#include <cairo.h>

struct swaylock_state;
void wallpaper_slide_start(struct swaylock_state *state);
void wallpaper_slide_stop(void);
cairo_surface_t *wallpaper_slide_image(void);

#endif
