#include "ReisenCrashSignal.h"

#include <errno.h>
#include <stdint.h>
#include <execinfo.h>
#include <fcntl.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <signal.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

enum { REISEN_CRASH_SIGNAL_PATH_MAX = 1024 };
enum { REISEN_CRASH_IMAGE_NAME_MAX = 64 };
enum { REISEN_CRASH_UUID_LEN = 37 };
enum { REISEN_CRASH_BREADCRUMB_LEN = 200 };
enum { REISEN_CRASH_PROVIDER_LEN = 64 };

typedef struct {
    char name[REISEN_CRASH_IMAGE_NAME_MAX];
    char uuid[REISEN_CRASH_UUID_LEN];
    uintptr_t start;
    uintptr_t end;
    intptr_t slide;
} CrashImage;

static char path_buf[REISEN_CRASH_SIGNAL_PATH_MAX];
static volatile sig_atomic_t opted_in;
static volatile sig_atomic_t already_written;

static CrashImage images[2][REISEN_CRASH_SIGNAL_MAX_IMAGES];
static volatile sig_atomic_t image_count[2];
static volatile sig_atomic_t image_slot;

static char breadcrumbs[2][REISEN_CRASH_SIGNAL_MAX_BREADCRUMBS][REISEN_CRASH_BREADCRUMB_LEN];
static volatile sig_atomic_t breadcrumb_next[2];
static volatile sig_atomic_t breadcrumb_count[2];
static volatile sig_atomic_t breadcrumb_slot;

static char provider_buf[2][REISEN_CRASH_PROVIDER_LEN];
static volatile sig_atomic_t provider_slot;
static const char provider_key[] = "provider=";
static volatile sig_atomic_t add_image_registered;

static void on_add_image(const struct mach_header *header, intptr_t slide);

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

static bool write_ull(int fd, unsigned long long value) {
    char digits[32];
    int count = 0;
    unsigned long long remaining = value;
    do {
        digits[count++] = (char)('0' + (remaining % 10));
        remaining /= 10;
    } while (remaining > 0 && count < 32);
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

static void copy_cstr(char *dst, size_t dst_len, const char *src) {
    if (dst_len == 0) {
        return;
    }
    if (src == NULL) {
        dst[0] = '\0';
        return;
    }
    size_t i = 0;
    while (src[i] != '\0' && i + 1 < dst_len) {
        dst[i] = src[i];
        i++;
    }
    dst[i] = '\0';
}

static void copy_basename(char *dst, size_t dst_len, const char *path) {
    const char *base = path;
    if (path != NULL) {
        for (const char *p = path; *p != '\0'; p++) {
            if (*p == '/') {
                base = p + 1;
            }
        }
    }
    copy_cstr(dst, dst_len, base);
}

static void format_uuid(const uint8_t bytes[16], char out[REISEN_CRASH_UUID_LEN]) {
    static const char hex[] = "0123456789ABCDEF";
    int o = 0;
    for (int i = 0; i < 16; i++) {
        if (i == 4 || i == 6 || i == 8 || i == 10) {
            out[o++] = '-';
        }
        out[o++] = hex[bytes[i] >> 4];
        out[o++] = hex[bytes[i] & 0xF];
    }
    out[o] = '\0';
}

static void store_image(
    int slot,
    int index,
    const char *name,
    const char *uuid,
    uintptr_t start,
    uintptr_t end,
    intptr_t slide
) {
    copy_cstr(images[slot][index].name, REISEN_CRASH_IMAGE_NAME_MAX, name);
    copy_cstr(images[slot][index].uuid, REISEN_CRASH_UUID_LEN, uuid);
    images[slot][index].start = start;
    images[slot][index].end = end;
    images[slot][index].slide = slide;
}

static bool parse_text_and_uuid(
    const struct mach_header *header,
    intptr_t slide,
    uintptr_t *start,
    uintptr_t *end,
    char uuid[REISEN_CRASH_UUID_LEN]
) {
    uuid[0] = '\0';
    bool have_text = false;
    if (header->magic != MH_MAGIC_64 && header->magic != MH_CIGAM_64) {
        return false;
    }
    const struct mach_header_64 *header64 = (const struct mach_header_64 *)header;
    const uint8_t *cursor = (const uint8_t *)(header64 + 1);
    for (uint32_t i = 0; i < header64->ncmds; i++) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)cursor;
            if (strncmp(segment->segname, SEG_TEXT, sizeof(segment->segname)) == 0) {
                *start = (uintptr_t)(segment->vmaddr + (uint64_t)slide);
                *end = *start + (uintptr_t)segment->vmsize;
                have_text = true;
            }
        } else if (command->cmd == LC_UUID) {
            const struct uuid_command *uuid_cmd = (const struct uuid_command *)cursor;
            format_uuid(uuid_cmd->uuid, uuid);
        }
        cursor += command->cmdsize;
    }
    return have_text;
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
    if (!add_image_registered) {
        add_image_registered = 1;
        _dyld_register_func_for_add_image(on_add_image);
    } else {
        reisen_crash_signal_refresh_images();
    }
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
    image_count[0] = 0;
    image_count[1] = 0;
    image_slot = 0;
    breadcrumb_next[0] = 0;
    breadcrumb_next[1] = 0;
    breadcrumb_count[0] = 0;
    breadcrumb_count[1] = 0;
    breadcrumb_slot = 0;
    provider_buf[0][0] = '\0';
    provider_buf[1][0] = '\0';
    provider_slot = 0;
    memset(breadcrumbs, 0, sizeof(breadcrumbs));
}

static void on_add_image(const struct mach_header *header, intptr_t slide) {
    (void)header;
    (void)slide;
    reisen_crash_signal_refresh_images();
}

void reisen_crash_signal_refresh_images(void) {
    int dest = 1 - (int)image_slot;
    uint32_t count = _dyld_image_count();
    int stored = 0;
    for (uint32_t i = 0; i < count && stored < REISEN_CRASH_SIGNAL_MAX_IMAGES; i++) {
        const struct mach_header *header = _dyld_get_image_header((unsigned)i);
        const char *name = _dyld_get_image_name((unsigned)i);
        if (header == NULL || name == NULL) {
            continue;
        }
        intptr_t slide = _dyld_get_image_vmaddr_slide((unsigned)i);
        uintptr_t start = 0;
        uintptr_t end = 0;
        char uuid[REISEN_CRASH_UUID_LEN];
        if (!parse_text_and_uuid(header, slide, &start, &end, uuid)) {
            continue;
        }
        char basename[REISEN_CRASH_IMAGE_NAME_MAX];
        copy_basename(basename, sizeof(basename), name);
        store_image(dest, stored, basename, uuid, start, end, slide);
        stored++;
    }
    image_count[dest] = stored;
    image_slot = dest;
}

void reisen_crash_signal_note_breadcrumb(const char *line) {
    if (line == NULL || line[0] == '\0') {
        return;
    }
    int published = (int)breadcrumb_slot;
    int dest = 1 - published;
    memcpy(
        breadcrumbs[dest],
        breadcrumbs[published],
        sizeof(breadcrumbs[dest])
    );
    int next = (int)breadcrumb_next[published];
    int count = (int)breadcrumb_count[published];
    copy_cstr(breadcrumbs[dest][next], REISEN_CRASH_BREADCRUMB_LEN, line);
    breadcrumb_next[dest] = (next + 1) % REISEN_CRASH_SIGNAL_MAX_BREADCRUMBS;
    breadcrumb_count[dest] = count < REISEN_CRASH_SIGNAL_MAX_BREADCRUMBS
        ? count + 1
        : count;
    breadcrumb_slot = dest;
}

void reisen_crash_signal_note_provider(const char *provider) {
    int dest = 1 - (int)provider_slot;
    copy_cstr(provider_buf[dest], REISEN_CRASH_PROVIDER_LEN, provider);
    provider_slot = dest;
}

bool reisen_crash_signal_note_image_for_tests(
    const char *name,
    uint64_t start,
    uint64_t end,
    const char *uuid,
    int64_t slide
) {
    if (name == NULL || name[0] == '\0') {
        return false;
    }
    int slot = (int)image_slot;
    int count = (int)image_count[slot];
    if (count >= REISEN_CRASH_SIGNAL_MAX_IMAGES) {
        return false;
    }
    store_image(slot, count, name, uuid, (uintptr_t)start, (uintptr_t)end, (intptr_t)slide);
    image_count[slot] = count + 1;
    return true;
}

static const CrashImage *image_containing(uintptr_t address) {
    int slot = (int)image_slot;
    int count = (int)image_count[slot];
    for (int i = 0; i < count; i++) {
        if (address >= images[slot][i].start && address < images[slot][i].end) {
            return &images[slot][i];
        }
    }
    return NULL;
}

static bool write_slide(int fd, intptr_t slide) {
    if (slide < 0) {
        return write_all(fd, "-", 1) >= 0 && write_hex(fd, (uintptr_t)(-slide));
    }
    return write_hex(fd, (uintptr_t)slide);
}

static bool write_frame(int fd, uintptr_t address) {
    if (!write_hex(fd, address)) {
        return false;
    }
    const CrashImage *image = image_containing(address);
    if (image != NULL) {
        if (write_all(fd, " ", 1) < 0
            || write_all(fd, image->name, strlen(image->name)) < 0
            || write_all(fd, " +", 2) < 0
            || !write_hex(fd, address - image->start)) {
            return false;
        }
    }
    return write_all(fd, "\n", 1) >= 0;
}

static bool image_contains_any_frame(
    const CrashImage *image,
    const uintptr_t *frames,
    int frame_count
) {
    if (image == NULL || frames == NULL) {
        return false;
    }
    for (int i = 0; i < frame_count; i++) {
        if (frames[i] >= image->start && frames[i] < image->end) {
            return true;
        }
    }
    return false;
}

static bool write_images(int fd, const uintptr_t *frames, int frame_count) {
    int slot = (int)image_slot;
    int count = (int)image_count[slot];
    int used = 0;
    for (int i = 0; i < count; i++) {
        if (image_contains_any_frame(&images[slot][i], frames, frame_count)) {
            used++;
        }
    }
    if (used <= 0) {
        return true;
    }
    if (write_all(fd, "images:\n", 8) < 0) {
        return false;
    }
    for (int i = 0; i < count; i++) {
        const CrashImage *image = &images[slot][i];
        if (!image_contains_any_frame(image, frames, frame_count)) {
            continue;
        }
        if (write_all(fd, image->name, strlen(image->name)) < 0
            || write_all(fd, " uuid=", 6) < 0
            || write_all(fd, image->uuid, strlen(image->uuid)) < 0
            || write_all(fd, " slide=", 7) < 0
            || !write_slide(fd, image->slide)
            || write_all(fd, " start=", 7) < 0
            || !write_hex(fd, image->start)
            || write_all(fd, " end=", 5) < 0
            || !write_hex(fd, image->end)
            || write_all(fd, "\n", 1) < 0) {
            return false;
        }
    }
    return true;
}

static bool write_breadcrumbs(int fd) {
    int slot = (int)breadcrumb_slot;
    int count = (int)breadcrumb_count[slot];
    if (count <= 0) {
        return true;
    }
    if (write_all(fd, "breadcrumbs:\n", 13) < 0) {
        return false;
    }
    int next = (int)breadcrumb_next[slot];
    int start = (next - count + REISEN_CRASH_SIGNAL_MAX_BREADCRUMBS)
        % REISEN_CRASH_SIGNAL_MAX_BREADCRUMBS;
    for (int i = 0; i < count; i++) {
        int index = (start + i) % REISEN_CRASH_SIGNAL_MAX_BREADCRUMBS;
        size_t length = strlen(breadcrumbs[slot][index]);
        if (write_all(fd, breadcrumbs[slot][index], length) < 0 || write_all(fd, "\n", 1) < 0) {
            return false;
        }
    }
    return true;
}

static bool write_signal_line(int fd, int sig) {
    const char *name = signal_name(sig);
    if (name != NULL) {
        return write_all(fd, name, strlen(name)) >= 0 && write_all(fd, "\n", 1) >= 0;
    }
    return write_all(fd, "SIGNAL ", 7) >= 0
        && write_decimal(fd, sig)
        && write_all(fd, "\n", 1) >= 0;
}

static bool write_key_ull(int fd, const char *key, unsigned long long value) {
    return write_all(fd, key, strlen(key)) >= 0
        && write_ull(fd, value)
        && write_all(fd, "\n", 1) >= 0;
}

static bool write_header(int fd, int sig) {
    if (!write_signal_line(fd, sig)) {
        return false;
    }
    time_t now = time(NULL);
    pid_t pid = getpid();
    if (!write_key_ull(fd, "time_unix=", now > 0 ? (unsigned long long)now : 0)
        || !write_key_ull(fd, "pid=", (unsigned long long)pid)) {
        return false;
    }
    int provider = (int)provider_slot;
    if (provider_buf[provider][0] == '\0') {
        return true;
    }
    return write_all(fd, provider_key, sizeof(provider_key) - 1) >= 0
        && write_all(fd, provider_buf[provider], strlen(provider_buf[provider])) >= 0
        && write_all(fd, "\n", 1) >= 0;
}

bool reisen_crash_signal_write_to_fd(int fd, int sig, const uintptr_t *frames, int frame_count) {
    if (fd < 0 || frame_count < 0 || (frame_count > 0 && frames == NULL)) {
        return false;
    }
    if (!write_header(fd, sig)) {
        return false;
    }
    for (int i = 0; i < frame_count; i++) {
        if (!write_frame(fd, frames[i])) {
            return false;
        }
    }
    return write_images(fd, frames, frame_count) && write_breadcrumbs(fd);
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
