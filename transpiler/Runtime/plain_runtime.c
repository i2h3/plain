#include "plain_runtime.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>
#include <errno.h>

#ifdef _WIN32
  #include <windows.h>
  #define PATH_SEP '\\'
#else
  #include <sys/ioctl.h>
  #define PATH_SEP '/'
#endif

// ─────────────────────────────────────────────
// Globals
// ─────────────────────────────────────────────

static int    g_argc  = 0;
static char** g_argv  = NULL;

void plain_runtime_init(int argc, char** argv) {
    g_argc = argc;
    g_argv = argv;
    srand((unsigned)time(NULL));
}

// ─────────────────────────────────────────────
// Memory
// ─────────────────────────────────────────────

void* plain_alloc(size_t size) {
    void* p = calloc(1, size);
    if (!p) { fprintf(stderr, "plain: out of memory\n"); exit(1); }
    return p;
}

void plain_retain(void* obj)  { if (obj) ((plain_refcount_t*)obj)[0]++; }
void plain_release(void* obj) { if (obj && --((plain_refcount_t*)obj)[0] <= 0) free(obj); }

// ─────────────────────────────────────────────
// Text
// ─────────────────────────────────────────────

plain_text_t plain_text_literal(const char* s) {
    return (plain_text_t){ .data = (char*)s, .length = strlen(s), .owned = false };
}

plain_text_t plain_text_from_cstr(const char* s) {
    size_t len = strlen(s);
    char*  buf = plain_alloc(len + 1);
    memcpy(buf, s, len + 1);
    return (plain_text_t){ .data = buf, .length = len, .owned = true };
}

const char* plain_text_cstr(plain_text_t t) {
    static char buf[4096];
    size_t n = t.length < sizeof(buf) - 1 ? t.length : sizeof(buf) - 1;
    memcpy(buf, t.data, n);
    buf[n] = '\0';
    return buf;
}

plain_text_t plain_text_concat(plain_text_t a, plain_text_t b) {
    size_t len = a.length + b.length;
    char*  buf = plain_alloc(len + 1);
    memcpy(buf, a.data, a.length);
    memcpy(buf + a.length, b.data, b.length);
    buf[len] = '\0';
    return (plain_text_t){ .data = buf, .length = len, .owned = true };
}

int64_t plain_text_length(plain_text_t t) { return (int64_t)t.length; }

bool plain_text_equal(plain_text_t a, plain_text_t b) {
    return a.length == b.length && memcmp(a.data, b.data, a.length) == 0;
}

bool plain_text_is_empty(plain_text_t t) { return t.length == 0; }

bool plain_text_is_prefix(plain_text_t prefix, plain_text_t text) {
    if (prefix.length > text.length) return false;
    return memcmp(prefix.data, text.data, prefix.length) == 0;
}

bool plain_text_is_suffix(plain_text_t suffix, plain_text_t text) {
    if (suffix.length > text.length) return false;
    return memcmp(suffix.data, text.data + (text.length - suffix.length), suffix.length) == 0;
}

bool plain_text_contains(plain_text_t text, plain_text_t needle) {
    if (needle.length > text.length) return false;
    for (size_t i = 0; i <= text.length - needle.length; i++) {
        if (memcmp(text.data + i, needle.data, needle.length) == 0) return true;
    }
    return false;
}

plain_text_t plain_text_uppercase(plain_text_t t) {
    char* buf = plain_alloc(t.length + 1);
    for (size_t i = 0; i < t.length; i++)
        buf[i] = (char)toupper((unsigned char)t.data[i]);
    buf[t.length] = '\0';
    return (plain_text_t){ .data = buf, .length = t.length, .owned = true };
}

plain_text_t plain_text_lowercase(plain_text_t t) {
    char* buf = plain_alloc(t.length + 1);
    for (size_t i = 0; i < t.length; i++)
        buf[i] = (char)tolower((unsigned char)t.data[i]);
    buf[t.length] = '\0';
    return (plain_text_t){ .data = buf, .length = t.length, .owned = true };
}

plain_text_t plain_text_trim(plain_text_t t) {
    size_t start = 0, end = t.length;
    while (start < end && isspace((unsigned char)t.data[start])) start++;
    while (end > start && isspace((unsigned char)t.data[end-1])) end--;
    size_t len = end - start;
    char* buf  = plain_alloc(len + 1);
    memcpy(buf, t.data + start, len);
    buf[len] = '\0';
    return (plain_text_t){ .data = buf, .length = len, .owned = true };
}

plain_text_t plain_text_reverse(plain_text_t t) {
    char* buf = plain_alloc(t.length + 1);
    for (size_t i = 0; i < t.length; i++)
        buf[i] = t.data[t.length - 1 - i];
    buf[t.length] = '\0';
    return (plain_text_t){ .data = buf, .length = t.length, .owned = true };
}

plain_text_t plain_text_substring(plain_text_t t, int64_t from, int64_t to) {
    if (from < 0) from = 0;
    if (to > (int64_t)t.length) to = (int64_t)t.length;
    if (from >= to) return plain_text_literal("");
    size_t len = (size_t)(to - from);
    char* buf  = plain_alloc(len + 1);
    memcpy(buf, t.data + from, len);
    buf[len] = '\0';
    return (plain_text_t){ .data = buf, .length = len, .owned = true };
}

plain_text_t plain_text_character_at(plain_text_t t, int64_t index) {
    if (index < 0 || index >= (int64_t)t.length) return plain_text_literal("");
    char* buf = plain_alloc(2);
    buf[0] = t.data[index];
    buf[1] = '\0';
    return (plain_text_t){ .data = buf, .length = 1, .owned = true };
}

// ─────────────────────────────────────────────
// Number / Decimal
// ─────────────────────────────────────────────

plain_text_t plain_number_to_text(int64_t n) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%" PRId64, n);
    return plain_text_from_cstr(buf);
}

plain_text_t plain_decimal_to_text(double d) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", d);
    return plain_text_from_cstr(buf);
}

plain_text_t plain_bool_to_text(bool b) {
    return plain_text_literal(b ? "true" : "false");
}

int64_t plain_text_to_number(plain_text_t t) {
    char* end;
    int64_t n = strtoll(plain_text_cstr(t), &end, 10);
    if (*end != '\0') {
        // TODO: throw parseFailure
        fprintf(stderr, "plain: cannot convert \"%s\" to number\n", plain_text_cstr(t));
        exit(1);
    }
    return n;
}

double plain_text_to_decimal(plain_text_t t) {
    char* end;
    double d = strtod(plain_text_cstr(t), &end);
    if (*end != '\0') {
        fprintf(stderr, "plain: cannot convert \"%s\" to decimal\n", plain_text_cstr(t));
        exit(1);
    }
    return d;
}

int64_t plain_round(double d)  { return (int64_t)round(d); }
int64_t plain_floor(double d)  { return (int64_t)floor(d); }
int64_t plain_ceil(double d)   { return (int64_t)ceil(d); }

double plain_round_places(double d, int64_t places) {
    double factor = pow(10.0, (double)places);
    return round(d * factor) / factor;
}
double plain_floor_places(double d, int64_t places) {
    double factor = pow(10.0, (double)places);
    return floor(d * factor) / factor;
}
double plain_ceil_places(double d, int64_t places) {
    double factor = pow(10.0, (double)places);
    return ceil(d * factor) / factor;
}

int64_t plain_abs(int64_t n)              { return n < 0 ? -n : n; }
double  plain_sqrt(double d)              { return sqrt(d); }
double  plain_pow(double b, double e)     { return pow(b, e); }
int64_t plain_remainder(int64_t a, int64_t b) { return a % b; }
int64_t plain_minimum_i(int64_t a, int64_t b) { return a < b ? a : b; }
int64_t plain_maximum_i(int64_t a, int64_t b) { return a > b ? a : b; }
double  plain_minimum_d(double a, double b)   { return a < b ? a : b; }
double  plain_maximum_d(double a, double b)   { return a > b ? a : b; }

// ─────────────────────────────────────────────
// Terminal
// ─────────────────────────────────────────────

static const char* plain_ansi_color(plain_text_t color) {
    const char* c = plain_text_cstr(color);
    if (strcmp(c, "black")   == 0) return "\033[30m";
    if (strcmp(c, "red")     == 0) return "\033[31m";
    if (strcmp(c, "green")   == 0) return "\033[32m";
    if (strcmp(c, "yellow")  == 0) return "\033[33m";
    if (strcmp(c, "blue")    == 0) return "\033[34m";
    if (strcmp(c, "magenta") == 0) return "\033[35m";
    if (strcmp(c, "cyan")    == 0) return "\033[36m";
    if (strcmp(c, "white")   == 0) return "\033[37m";
    return "";
}

static const char* plain_ansi_style(const char* style) {
    if (!style) return "";
    if (strcmp(style, "bold")      == 0) return "\033[1m";
    if (strcmp(style, "italic")    == 0) return "\033[3m";
    if (strcmp(style, "underline") == 0) return "\033[4m";
    if (strcmp(style, "dim")       == 0) return "\033[2m";
    return "";
}

void plain_print(FILE* dest, plain_text_t value) {
    fprintf(dest, "%.*s\n", (int)value.length, value.data);
}

void plain_print_styled(FILE* dest, plain_text_t value, plain_text_t color, const char* style) {
    fprintf(dest, "%s%s%.*s\033[0m\n",
            plain_ansi_color(color),
            plain_ansi_style(style),
            (int)value.length, value.data);
}

plain_text_t plain_input(plain_text_t* prompt) {
    if (prompt) fprintf(stdout, "%.*s", (int)prompt->length, prompt->data);
    fflush(stdout);
    char buf[4096];
    if (!fgets(buf, sizeof(buf), stdin)) return plain_text_literal("");
    size_t len = strlen(buf);
    if (len > 0 && buf[len-1] == '\n') buf[--len] = '\0';
    return plain_text_from_cstr(buf);
}

void plain_terminal_clear(void) {
#ifdef _WIN32
    system("cls");
#else
    printf("\033[2J\033[H");
    fflush(stdout);
#endif
}

int64_t plain_terminal_width(void) {
#ifdef _WIN32
    CONSOLE_SCREEN_BUFFER_INFO csbi;
    GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi);
    return csbi.srWindow.Right - csbi.srWindow.Left + 1;
#else
    struct winsize w;
    ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
    return w.ws_col;
#endif
}

int64_t plain_terminal_height(void) {
#ifdef _WIN32
    CONSOLE_SCREEN_BUFFER_INFO csbi;
    GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi);
    return csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
#else
    struct winsize w;
    ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
    return w.ws_row;
#endif
}

// ─────────────────────────────────────────────
// Environment
// ─────────────────────────────────────────────

plain_text_t plain_env_get(plain_text_t key) {
    const char* v = getenv(plain_text_cstr(key));
    if (!v) return plain_text_literal("");
    return plain_text_from_cstr(v);
}

plain_list_t plain_arguments(void) {
    plain_list_t list = plain_list_new();
    for (int i = 1; i < g_argc; i++) {
        plain_text_t* t = plain_alloc(sizeof(plain_text_t));
        *t = plain_text_from_cstr(g_argv[i]);
        plain_list_add(&list, t);
    }
    return list;
}

plain_text_t plain_os_name(void) {
#if defined(_WIN32)
    return plain_text_literal("windows");
#elif defined(__APPLE__)
    return plain_text_literal("macos");
#else
    return plain_text_literal("linux");
#endif
}

// ─────────────────────────────────────────────
// Random
// ─────────────────────────────────────────────

int64_t plain_random_number(void)                      { return (int64_t)rand(); }
int64_t plain_random_between(int64_t min, int64_t max) { return min + rand() % (max - min + 1); }
double  plain_random_decimal(void)                     { return (double)rand() / RAND_MAX; }
bool    plain_random_bool(void)                        { return rand() % 2; }

void* plain_random_item(plain_list_t* list) {
    if (!list->count) return NULL;
    return plain_list_get(list, (size_t)(rand() % list->count));
}

// ─────────────────────────────────────────────
// Lists
// ─────────────────────────────────────────────

plain_list_t plain_list_new(void) {
    plain_list_t l = {0};
    l.capacity = 8;
    l.items    = plain_alloc(l.capacity * sizeof(void*));
    return l;
}

void plain_list_add(plain_list_t* l, void* item) {
    if (l->count >= l->capacity) {
        l->capacity *= 2;
        l->items     = realloc(l->items, l->capacity * sizeof(void*));
    }
    l->items[l->count++] = item;
}

void* plain_list_get(plain_list_t* l, size_t i) {
    if (i >= l->count) return NULL;
    return l->items[i];
}

void plain_list_set(plain_list_t* l, size_t i, void* item) {
    if (i < l->count) l->items[i] = item;
}

void plain_list_remove_at(plain_list_t* l, size_t i) {
    if (i >= l->count) return;
    memmove(l->items + i, l->items + i + 1, (l->count - i - 1) * sizeof(void*));
    l->count--;
}

size_t plain_list_count(plain_list_t* l) { return l->count; }
bool   plain_list_is_empty(plain_list_t* l) { return l->count == 0; }

// ─────────────────────────────────────────────
// Path
// ─────────────────────────────────────────────

plain_path_t plain_path_of(plain_text_t s) { return s; }

plain_path_t plain_path_join(plain_path_t a, plain_path_t b) {
    char sep[2] = { PATH_SEP, '\0' };
    plain_text_t s = plain_text_from_cstr(sep);
    return plain_text_concat(plain_text_concat(a, s), b);
}

plain_text_t plain_path_name(plain_path_t p) {
    const char* s = plain_text_cstr(p);
    const char* last = strrchr(s, PATH_SEP);
    const char* base = last ? last + 1 : s;
    const char* dot  = strrchr(base, '.');
    if (!dot) return plain_text_from_cstr(base);
    return plain_text_substring(plain_text_from_cstr(base), 0, (int64_t)(dot - base));
}

plain_text_t plain_path_extension(plain_path_t p) {
    const char* s   = plain_text_cstr(p);
    const char* dot = strrchr(s, '.');
    if (!dot) return plain_text_literal("");
    return plain_text_from_cstr(dot + 1);
}

plain_text_t plain_path_full_name(plain_path_t p) {
    const char* s    = plain_text_cstr(p);
    const char* last = strrchr(s, PATH_SEP);
    return plain_text_from_cstr(last ? last + 1 : s);
}

plain_path_t plain_path_parent(plain_path_t p) {
    const char* s    = plain_text_cstr(p);
    const char* last = strrchr(s, PATH_SEP);
    if (!last) return plain_text_literal(".");
    return plain_text_substring(p, 0, (int64_t)(last - s));
}

plain_path_t plain_path_home(void) {
    const char* h = getenv("HOME");
#ifdef _WIN32
    if (!h) h = getenv("USERPROFILE");
#endif
    return plain_text_from_cstr(h ? h : ".");
}

plain_path_t plain_path_temp(void) {
#ifdef _WIN32
    char buf[MAX_PATH];
    GetTempPathA(MAX_PATH, buf);
    return plain_text_from_cstr(buf);
#else
    return plain_text_from_cstr("/tmp");
#endif
}

plain_path_t plain_path_cwd(void) {
    char buf[4096];
    return plain_text_from_cstr(getcwd(buf, sizeof(buf)) ? buf : ".");
}

// ─────────────────────────────────────────────
// File system
// ─────────────────────────────────────────────

plain_text_t plain_file_read(plain_path_t path) {
    FILE* f = fopen(plain_text_cstr(path), "rb");
    if (!f) { fprintf(stderr, "plain: cannot open '%s'\n", plain_text_cstr(path)); exit(1); }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    rewind(f);
    char* buf = plain_alloc((size_t)size + 1);
    fread(buf, 1, (size_t)size, f);
    buf[size] = '\0';
    fclose(f);
    return (plain_text_t){ .data = buf, .length = (size_t)size, .owned = true };
}

void plain_file_write(plain_path_t path, plain_text_t content) {
    FILE* f = fopen(plain_text_cstr(path), "wb");
    if (!f) { fprintf(stderr, "plain: cannot write '%s'\n", plain_text_cstr(path)); exit(1); }
    fwrite(content.data, 1, content.length, f);
    fclose(f);
}

void plain_file_append(plain_path_t path, plain_text_t content) {
    FILE* f = fopen(plain_text_cstr(path), "ab");
    if (!f) { fprintf(stderr, "plain: cannot append '%s'\n", plain_text_cstr(path)); exit(1); }
    fwrite(content.data, 1, content.length, f);
    fclose(f);
}

bool plain_file_exists(plain_path_t path) {
    struct stat s;
    return stat(plain_text_cstr(path), &s) == 0 && S_ISREG(s.st_mode);
}

void plain_file_delete(plain_path_t path) { remove(plain_text_cstr(path)); }

bool plain_dir_exists(plain_path_t path) {
    struct stat s;
    return stat(plain_text_cstr(path), &s) == 0 && S_ISDIR(s.st_mode);
}

void plain_dir_create(plain_path_t path) {
#ifdef _WIN32
    mkdir(plain_text_cstr(path));
#else
    mkdir(plain_text_cstr(path), 0755);
#endif
}

void plain_dir_delete(plain_path_t path) { rmdir(plain_text_cstr(path)); }

// ─────────────────────────────────────────────
// Channels
// ─────────────────────────────────────────────

plain_channel_t* plain_channel_new(size_t capacity) {
    plain_channel_t* ch = plain_alloc(sizeof(plain_channel_t));
    ch->buffer   = plain_alloc(capacity * sizeof(void*));
    ch->capacity = capacity;
    pthread_mutex_init(&ch->mutex, NULL);
    pthread_cond_init(&ch->not_empty, NULL);
    pthread_cond_init(&ch->not_full, NULL);
    return ch;
}

void plain_channel_send(plain_channel_t* ch, void* value) {
    pthread_mutex_lock(&ch->mutex);
    while (ch->count == ch->capacity && !ch->closed)
        pthread_cond_wait(&ch->not_full, &ch->mutex);
    if (!ch->closed) {
        ch->buffer[ch->tail] = value;
        ch->tail = (ch->tail + 1) % ch->capacity;
        ch->count++;
        pthread_cond_signal(&ch->not_empty);
    }
    pthread_mutex_unlock(&ch->mutex);
}

void* plain_channel_receive(plain_channel_t* ch) {
    pthread_mutex_lock(&ch->mutex);
    while (ch->count == 0 && !ch->closed)
        pthread_cond_wait(&ch->not_empty, &ch->mutex);
    void* value = NULL;
    if (ch->count > 0) {
        value    = ch->buffer[ch->head];
        ch->head = (ch->head + 1) % ch->capacity;
        ch->count--;
        pthread_cond_signal(&ch->not_full);
    }
    pthread_mutex_unlock(&ch->mutex);
    return value;
}

void plain_channel_close(plain_channel_t* ch) {
    pthread_mutex_lock(&ch->mutex);
    ch->closed = true;
    pthread_cond_broadcast(&ch->not_empty);
    pthread_cond_broadcast(&ch->not_full);
    pthread_mutex_unlock(&ch->mutex);
}

bool plain_channel_is_closed(plain_channel_t* ch) { return ch->closed; }

// ─────────────────────────────────────────────
// Generic helpers
// ─────────────────────────────────────────────

bool plain_equal(plain_text_t a, plain_text_t b) { return plain_text_equal(a, b); }

bool plain_contains(plain_list_t* list, void* item) {
    for (size_t i = 0; i < list->count; i++)
        if (list->items[i] == item) return true;
    return false;
}

void* plain_add(plain_text_t a, plain_text_t b) {
    return (void*)&plain_text_concat(a, b);
}
