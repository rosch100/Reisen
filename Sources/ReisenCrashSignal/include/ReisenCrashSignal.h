#pragma once

#include <stdbool.h>
#include <stdint.h>

enum { REISEN_CRASH_SIGNAL_MAX_FRAMES = 32 };

bool reisen_crash_signal_prepare(const char *path, bool opted_in);
void reisen_crash_signal_set_opted_in(bool opted_in);
void reisen_crash_signal_mark_written(void);
void reisen_crash_signal_reset_for_tests(void);
bool reisen_crash_signal_write_to_fd(int fd, int sig, const uintptr_t *frames, int frame_count);
bool reisen_crash_signal_write_current(int sig);
bool reisen_crash_signal_install(bool debugger_attached);
