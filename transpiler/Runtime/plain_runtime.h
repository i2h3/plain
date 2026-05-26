#ifndef PLAIN_RUNTIME_H
#define PLAIN_RUNTIME_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <setjmp.h>
#include <pthread.h>

// ─────────────────────────────────────────────
// Initialisation
// ─────────────────────────────────────────────

void plain_runtime_init(int argc, char** argv);

// ─────────────────────────────────────────────
// Memory
// ─────────────────────────────────────────────

typedef int32_t plain_refcount_t;

void* plain_alloc(size_t size);
void  plain_retain(void* obj);
void  plain_release(void* obj);

// ─────────────────────────────────────────────
// Text
// ─────────────────────────────────────────────

typedef struct {
    char*   data;
    size_t  length;
    bool    owned;
} plain_text_t;

plain_text_t  plain_text_literal(const char* s);
plain_text_t  plain_text_from_cstr(const char* s);
plain_text_t  plain_text_concat(plain_text_t a, plain_text_t b);
plain_text_t  plain_to_text(plain_text_t v);        // generic — overloaded by type
int64_t       plain_text_length(plain_text_t t);
plain_text_t  plain_text_uppercase(plain_text_t t);
plain_text_t  plain_text_lowercase(plain_text_t t);
plain_text_t  plain_text_trim(plain_text_t t);
plain_text_t  plain_text_reverse(plain_text_t t);
plain_text_t  plain_text_replacement(plain_text_t src, plain_text_t old, plain_text_t new);
bool          plain_text_is_prefix(plain_text_t prefix, plain_text_t text);
bool          plain_text_is_suffix(plain_text_t suffix, plain_text_t text);
bool          plain_text_contains(plain_text_t text, plain_text_t needle);
bool          plain_text_is_empty(plain_text_t t);
plain_text_t  plain_text_substring(plain_text_t t, int64_t from, int64_t to);
plain_text_t  plain_text_character_at(plain_text_t t, int64_t index);
plain_text_t  plain_text_left_padding(plain_text_t t, int64_t length, plain_text_t pad);
plain_text_t  plain_text_right_padding(plain_text_t t, int64_t length, plain_text_t pad);
int64_t       plain_text_to_number(plain_text_t t);
double        plain_text_to_decimal(plain_text_t t);
bool          plain_text_equal(plain_text_t a, plain_text_t b);
const char*   plain_text_cstr(plain_text_t t);

// ─────────────────────────────────────────────
// Number / Decimal
// ─────────────────────────────────────────────

plain_text_t  plain_number_to_text(int64_t n);
plain_text_t  plain_decimal_to_text(double d);
plain_text_t  plain_bool_to_text(bool b);
int64_t       plain_round(double d);
int64_t       plain_floor(double d);
int64_t       plain_ceil(double d);
double        plain_round_places(double d, int64_t places);
double        plain_floor_places(double d, int64_t places);
double        plain_ceil_places(double d, int64_t places);
int64_t       plain_abs(int64_t n);
double        plain_sqrt(double d);
double        plain_pow(double base, double exp);
int64_t       plain_remainder(int64_t a, int64_t b);
int64_t       plain_minimum_i(int64_t a, int64_t b);
int64_t       plain_maximum_i(int64_t a, int64_t b);
double        plain_minimum_d(double a, double b);
double        plain_maximum_d(double a, double b);

// ─────────────────────────────────────────────
// Lists
// ─────────────────────────────────────────────

typedef struct {
    void**  items;
    size_t  count;
    size_t  capacity;
} plain_list_t;

plain_list_t  plain_list_new(void);
void          plain_list_add(plain_list_t* list, void* item);
void          plain_list_remove_at(plain_list_t* list, size_t index);
void*         plain_list_get(plain_list_t* list, size_t index);
void          plain_list_set(plain_list_t* list, size_t index, void* item);
size_t        plain_list_count(plain_list_t* list);
bool          plain_list_is_empty(plain_list_t* list);
plain_list_t  plain_list_shuffle(plain_list_t list);
void*         plain_random_item(plain_list_t* list);
plain_text_t  plain_text_join(plain_list_t* list, plain_text_t separator);
plain_list_t  plain_text_parts(plain_text_t text, plain_text_t separator);
plain_list_t  plain_text_words(plain_text_t text);
plain_list_t  plain_text_lines(plain_text_t text);
plain_list_t  plain_text_positions(plain_text_t text, plain_text_t needle);
double        plain_list_sum(plain_list_t* list);
double        plain_list_average(plain_list_t* list);

#define PLAIN_FOR_EACH(var, list) \
    for (size_t _i = 0; _i < plain_list_count(&(list)) && \
         ((__typeof__(var)) (var = plain_list_get(&(list), _i))) != NULL; _i++)

// ─────────────────────────────────────────────
// Maps
// ─────────────────────────────────────────────

typedef struct plain_map_entry {
    plain_text_t           key;
    void*                  value;
    struct plain_map_entry* next;
} plain_map_entry_t;

typedef struct {
    plain_map_entry_t** buckets;
    size_t              bucket_count;
    size_t              count;
} plain_map_t;

plain_map_t   plain_map_new(void);
void          plain_map_set(plain_map_t* map, plain_text_t key, void* value);
void*         plain_map_get(plain_map_t* map, plain_text_t key);
bool          plain_map_has(plain_map_t* map, plain_text_t key);
void          plain_map_remove(plain_map_t* map, plain_text_t key);

// ─────────────────────────────────────────────
// Moment (date/time)
// ─────────────────────────────────────────────

typedef struct {
    int64_t year, month, day;
    int64_t hour, minute, second, millisecond;
} plain_moment_t;

plain_moment_t plain_moment_now(void);
plain_moment_t plain_moment_of(int64_t year, int64_t month, int64_t day,
                                int64_t hour, int64_t minute, int64_t second, int64_t ms);
plain_moment_t plain_moment_add(plain_moment_t m, int64_t amount, const char* unit);
plain_moment_t plain_moment_subtract(plain_moment_t m, int64_t amount, const char* unit);
bool           plain_moment_before(plain_moment_t a, plain_moment_t b);
bool           plain_moment_after(plain_moment_t a, plain_moment_t b);
bool           plain_moment_same(plain_moment_t a, plain_moment_t b);
int64_t        plain_moment_diff(plain_moment_t a, plain_moment_t b, const char* unit);
plain_text_t   plain_moment_format(plain_moment_t m, plain_text_t fmt);
plain_moment_t plain_moment_parse(plain_text_t text, plain_text_t fmt);

// ─────────────────────────────────────────────
// Path
// ─────────────────────────────────────────────

typedef plain_text_t plain_path_t;

plain_path_t  plain_path_of(plain_text_t s);
plain_path_t  plain_path_join(plain_path_t a, plain_path_t b);
plain_text_t  plain_path_name(plain_path_t p);
plain_text_t  plain_path_extension(plain_path_t p);
plain_text_t  plain_path_full_name(plain_path_t p);
plain_path_t  plain_path_parent(plain_path_t p);
plain_path_t  plain_path_home(void);
plain_path_t  plain_path_temp(void);
plain_path_t  plain_path_cwd(void);
plain_text_t  plain_path_to_text(plain_path_t p);

// ─────────────────────────────────────────────
// File system
// ─────────────────────────────────────────────

plain_text_t  plain_file_read(plain_path_t path);
void          plain_file_write(plain_path_t path, plain_text_t content);
void          plain_file_append(plain_path_t path, plain_text_t content);
bool          plain_file_exists(plain_path_t path);
void          plain_file_delete(plain_path_t path);
void          plain_file_copy(plain_path_t src, plain_path_t dst);
void          plain_file_move(plain_path_t src, plain_path_t dst);
int64_t       plain_file_size(plain_path_t path);
plain_moment_t plain_file_modification_date(plain_path_t path);
bool          plain_dir_exists(plain_path_t path);
void          plain_dir_create(plain_path_t path);
void          plain_dir_delete(plain_path_t path);
plain_list_t  plain_dir_contents(plain_path_t path);

// ─────────────────────────────────────────────
// Networking
// ─────────────────────────────────────────────

typedef struct {
    int64_t      status;
    plain_text_t body;
    plain_map_t  headers;
} plain_response_t;

plain_response_t* plain_http_get(plain_text_t url, plain_map_t headers);
plain_response_t* plain_http_post(plain_text_t url, plain_text_t body, plain_map_t headers);
plain_response_t* plain_http_put(plain_text_t url, plain_text_t body, plain_map_t headers);
plain_response_t* plain_http_patch(plain_text_t url, plain_text_t body, plain_map_t headers);
plain_response_t* plain_http_delete(plain_text_t url, plain_map_t headers);

// ─────────────────────────────────────────────
// JSON
// ─────────────────────────────────────────────

typedef struct plain_json plain_json_t;

plain_json_t*  plain_json_parse(plain_text_t source);
plain_text_t   plain_json_encode(plain_json_t* json);
plain_json_t*  plain_json_object_new(void);
plain_json_t*  plain_json_array_new(void);
void           plain_json_set(plain_json_t* obj, plain_text_t key, plain_json_t* value);
plain_json_t*  plain_json_get(plain_json_t* obj, plain_text_t key);
plain_text_t   plain_json_text_of(plain_json_t* json, plain_text_t key);
int64_t        plain_json_number_of(plain_json_t* json, plain_text_t key);
double         plain_json_decimal_of(plain_json_t* json, plain_text_t key);
bool           plain_json_bool_of(plain_json_t* json, plain_text_t key);
plain_json_t*  plain_json_object_of(plain_json_t* json, plain_text_t key);
plain_list_t   plain_json_list_of(plain_json_t* json, plain_text_t key);
plain_json_t*  plain_json_from_text(plain_text_t t);
plain_json_t*  plain_json_from_number(int64_t n);
plain_json_t*  plain_json_from_decimal(double d);
plain_json_t*  plain_json_from_bool(bool b);

// ─────────────────────────────────────────────
// Terminal
// ─────────────────────────────────────────────

void          plain_print(FILE* dest, plain_text_t value);
void          plain_print_styled(FILE* dest, plain_text_t value,
                                  plain_text_t color, const char* style);
plain_text_t  plain_input(plain_text_t* prompt);
void          plain_terminal_clear(void);
int64_t       plain_terminal_width(void);
int64_t       plain_terminal_height(void);

// ─────────────────────────────────────────────
// Environment
// ─────────────────────────────────────────────

plain_text_t  plain_env_get(plain_text_t key);
plain_list_t  plain_arguments(void);
plain_text_t  plain_os_name(void);

// ─────────────────────────────────────────────
// Random
// ─────────────────────────────────────────────

int64_t       plain_random_number(void);
int64_t       plain_random_between(int64_t min, int64_t max);
double        plain_random_decimal(void);
bool          plain_random_bool(void);

// ─────────────────────────────────────────────
// Channels
// ─────────────────────────────────────────────

typedef struct {
    void**          buffer;
    size_t          capacity;
    size_t          head, tail, count;
    bool            closed;
    pthread_mutex_t mutex;
    pthread_cond_t  not_empty;
    pthread_cond_t  not_full;
} plain_channel_t;

plain_channel_t* plain_channel_new(size_t capacity);
void             plain_channel_send(plain_channel_t* ch, void* value);
void*            plain_channel_receive(plain_channel_t* ch);
void             plain_channel_close(plain_channel_t* ch);
bool             plain_channel_is_closed(plain_channel_t* ch);

// ─────────────────────────────────────────────
// Error handling
// ─────────────────────────────────────────────

typedef struct {
    int         type_id;
    plain_text_t message;
} plain_error_base_t;

typedef plain_error_base_t plain_error_t;

void             plain_try_begin(void);
jmp_buf*         plain_try_env(void);
void             plain_try_end(void);
void             plain_throw(plain_error_t* error);
bool             plain_catch_is(int type_id);
plain_error_t*   plain_catch_error(void);

#define PLAIN_SHARED_INIT(val) { .value = (val), .mutex = PTHREAD_MUTEX_INITIALIZER }

// ─────────────────────────────────────────────
// Equality and generic helpers
// ─────────────────────────────────────────────

bool plain_equal(plain_text_t a, plain_text_t b);
bool plain_contains(plain_list_t* list, void* item);
void* plain_add(plain_text_t a, plain_text_t b); // text concat fallback

#endif // PLAIN_RUNTIME_H
