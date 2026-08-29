#include "ReisenCrashSignal.h"

#include <errno.h>
#include <execinfo.h>
#include <fcntl.h>
#include <signal.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

enum { REISEN_CRASH_SIGNAL_PATH_MAX = 1024 };

static char path_buf[REISEN_CRASH_SIGNAL_PATH_MAX];
static volatile sig_atomic_t opted_in;
static volatile sig_atomic_t already_written;

static ssize_t write_all(int fd, const char *bytes, size_t length) {
    size_t offset = 0;
    while (offset < length) {
        ssize_t n = write(fd, bytes + offset, length - offset);
        if (n < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        if (n == 0) {
            return -1;
        }
        offset += (size_t)n;
    }
    return (ssize_t)offset;
}

static const char *signal_name(int sig) {
    switch (sig) {
    case SIGTRAP:
        return "SIGTRAP";
    case SIGABRT:
        return "SIGABRT";
    case SIGSEGV:
        return "SIGSEGV";
    case SIGBUS:
        return "SIGBUS";
    case SIGILL:
        return "SIGILL";
    case SIGFPE:
        return "SIGFPE";
    default:
        return NULL;
    }
}

static bool write_decimal(int fd, int value) {
    if (value < 0) {
        if (write_all(fd, "-", 1) < 0) {
            return false;
        }
        value = -value;
    }
    char digits[16];
    int count = 0;
    int remaining = value;
    do {
        digits[count++] = (char)('0' + (remaining % 10));
        remaining /= 10;
    } while (remaining > 0 && count < 16);
    for (int i = count - 1; i >= 0; i--) {
        if (write_all(fd, &digits[i], 1) < 0) {
            return false;
        }
    }
    return true;
}

static bool write_hex(int fd, uintptr_t value) {
    static const char hex[] = "0123456789abcdef";
    if (write_all(fd, "0x", 2) < 0) {
        return false;
    }
    int started = 0;
    for (int shift = (int)(sizeof(uintptr_t) * 8) - 4; shift >= 0; shift -= 4) {
        unsigned digit = (unsigned)((value >> shift) & 0xF);
        if (digit != 0 || started || shift == 0) {
            started = 1;
            char ch = hex[digit];
            if (write_all(fd, &ch, 1) < 0) {
                return false;
            }
        }
    }
    return true;
}

bool reisen_crash_signal_prepare(const char *path, bool is_opted_in) {
    already_written = 0;
    opted_in = is_opted_in ? 1 : 0;
    path_buf[0] = '\0';
    if (path == NULL || path[0] == '\0') {
        return false;
    }
    size_t length = strlen(path);
    if (length >= REISEN_CRASH_SIGNAL_PATH_MAX) {
        return false;
    }
    memcpy(path_buf, path, length + 1);
    return true;
}

void reisen_crash_signal_set_opted_in(bool is_opted_in) {
    opted_in = is_opted_in ? 1 : 0;
}

void reisen_crash_signal_mark_written(void) {
    already_written = 1;
}

void reisen_crash_signal_reset_for_tests(void) {
    path_buf[0] = '\0';
    opted_in = 0;
    already_written = 0;
}

bool reisen_crash_signal_write_to_fd(int fd, int sig, const uintptr_t *frames, int frame_count) {
    if (fd < 0 || frame_count < 0 || (frame_count > 0 && frames == NULL)) {
        return false;
    }
    const char *name = signal_name(sig);
    if (name != NULL) {
        if (write_all(fd, name, strlen(name)) < 0) {
            return false;
        }
    } else {
        if (write_all(fd, "SIGNAL ", 7) < 0 || !write_decimal(fd, sig)) {
            return false;
        }
    }
    if (write_all(fd, "\n", 1) < 0) {
        return false;
    }
    for (int i = 0; i < frame_count; i++) {
        if (!write_hex(fd, frames[i]) || write_all(fd, "\n", 1) < 0) {
            return false;
        }
    }
    return true;
}

bool reisen_crash_signal_write_current(int sig) {
    if (!opted_in || already_written || path_buf[0] == '\0') {
        return false;
    }
    int fd = open(path_buf, O_CREAT | O_WRONLY | O_EXCL, S_IRUSR | S_IWUSR);
    if (fd < 0) {
        return false;
    }
    void *stack[REISEN_CRASH_SIGNAL_MAX_FRAMES];
    int raw_count = backtrace(stack, REISEN_CRASH_SIGNAL_MAX_FRAMES);
    uintptr_t frames[REISEN_CRASH_SIGNAL_MAX_FRAMES];
    int count = raw_count < 0 ? 0 : raw_count;
    if (count > REISEN_CRASH_SIGNAL_MAX_FRAMES) {
        count = REISEN_CRASH_SIGNAL_MAX_FRAMES;
    }
    for (int i = 0; i < count; i++) {
        frames[i] = (uintptr_t)stack[i];
    }
    bool ok = reisen_crash_signal_write_to_fd(fd, sig, frames, count);
    close(fd);
    if (ok) {
        already_written = 1;
    } else {
        (void)unlink(path_buf);
    }
    return ok;
}

static void reisen_crash_signal_handle(int sig) {
    (void)reisen_crash_signal_write_current(sig);
    signal(sig, SIG_DFL);
    raise(sig);
}

bool reisen_crash_signal_install(bool debugger_attached) {
    if (debugger_attached) {
        return false;
    }
    static const int signals[] = {SIGTRAP, SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE};
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = reisen_crash_signal_handle;
    action.sa_flags = SA_RESETHAND;
    sigemptyset(&action.sa_mask);
    for (size_t i = 0; i < sizeof(signals) / sizeof(signals[0]); i++) {
        if (sigaction(signals[i], &action, NULL) != 0) {
            return false;
        }
    }
    return true;
}
