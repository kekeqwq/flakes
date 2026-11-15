#ifndef SWAYLOCK_KEY_AUTH_H
#define SWAYLOCK_KEY_AUTH_H
#include <stdbool.h>
/* Success: 1, no complete notification: 0, closed/failed helper: -1. */
int key_auth_start(void);
int key_auth_read(int fd);
bool key_auth_expired(void);
void key_auth_stop(void);
#endif
